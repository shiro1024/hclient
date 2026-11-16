//! File, caller-buffer and owned display-buffer content codec ABI.
//!
//! JPEG/PNG/GIF use precomp2 + zstd when smaller. Other formats stay raw.

mod page_codec;

use sha2::{Digest, Sha256};
use std::{
    fs::{File, OpenOptions},
    io::{Read, Write},
    mem::align_of,
    panic::{AssertUnwindSafe, catch_unwind},
    path::Path,
};

const RAW: u32 = 0;
const IO_BUFFER_SIZE: usize = 64 * 1024;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(i32)]
enum CodecError {
    Argument = 1,
    Io = 2,
    Identity = 3,
    UnsupportedProfile = 4,
    Panic = 5,
}

impl From<std::io::Error> for CodecError {
    fn from(_: std::io::Error) -> Self {
        Self::Io
    }
}

#[repr(C)]
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
pub struct CodecResult {
    pub codec: u32,
    pub raw_length: u64,
    pub stored_length: u64,
    pub raw_hash: [u8; 32],
    pub object_hash: [u8; 32],
}

impl CodecResult {
    fn raw(length: u64, hash: [u8; 32]) -> Self {
        Self {
            codec: RAW,
            raw_length: length,
            stored_length: length,
            raw_hash: hash,
            object_hash: hash,
        }
    }
}

/// Owns only a newly created output. Never removes a pre-existing path.
struct OutputFile<'a> {
    file: Option<File>,
    path: &'a Path,
    complete: bool,
}

impl<'a> OutputFile<'a> {
    fn create(path: &'a Path) -> Result<Self, CodecError> {
        let file = OpenOptions::new().write(true).create_new(true).open(path)?;
        Ok(Self {
            file: Some(file),
            path,
            complete: false,
        })
    }

    fn finish(mut self) {
        self.file.take();
        self.complete = true;
    }
}

impl Drop for OutputFile<'_> {
    fn drop(&mut self) {
        self.file.take();
        if !self.complete {
            let _ = std::fs::remove_file(self.path);
        }
    }
}

fn open_input(path: &Path) -> Result<File, CodecError> {
    let file = File::open(path)?;
    if !file.metadata()?.is_file() {
        return Err(CodecError::Argument);
    }
    Ok(file)
}

fn encode_file(input: &Path, output: &Path) -> Result<CodecResult, CodecError> {
    page_codec::encode(input, output)
}

fn decode_file(
    input: &Path,
    output: &Path,
    codec: u32,
    raw_length: u64,
    raw_hash: [u8; 32],
) -> Result<CodecResult, CodecError> {
    let mut destination = OutputFile::create(output)?;
    let restored = decode_bytes(input, codec, raw_length, raw_hash)?;
    destination
        .file
        .as_mut()
        .ok_or(CodecError::Io)?
        .write_all(&restored)?;
    destination.finish();
    Ok(CodecResult::raw(raw_length, raw_hash))
}

fn decode_bytes(
    input: &Path,
    codec: u32,
    raw_length: u64,
    raw_hash: [u8; 32],
) -> Result<Vec<u8>, CodecError> {
    if codec == page_codec::PROFILE {
        return page_codec::decode_bytes(input, raw_length, raw_hash);
    }
    if codec != RAW {
        return Err(CodecError::UnsupportedProfile);
    }
    let mut reader = open_input(input)?;
    if reader.metadata()?.len() != raw_length {
        return Err(CodecError::Identity);
    }
    let mut restored = Vec::new();
    reader.read_to_end(&mut restored)?;
    if restored.len() as u64 != raw_length
        || <[u8; 32]>::from(Sha256::digest(&restored)) != raw_hash
    {
        return Err(CodecError::Identity);
    }
    Ok(restored)
}

fn decode_image_for_display(input: &Path, codec: u32) -> Result<Vec<u8>, CodecError> {
    match codec {
        RAW => {
            let mut bytes = Vec::new();
            open_input(input)?.read_to_end(&mut bytes)?;
            Ok(bytes)
        }
        page_codec::PROFILE => page_codec::decode_image_for_display(input),
        _ => Err(CodecError::UnsupportedProfile),
    }
}

#[repr(C)]
#[derive(Debug)]
pub struct CodecBuffer {
    pub data: *mut u8,
    pub length: usize,
}

impl Default for CodecBuffer {
    fn default() -> Self {
        Self {
            data: std::ptr::null_mut(),
            length: 0,
        }
    }
}

/// # Safety
/// Input must reference a readable UTF-8 path. `output` must be aligned writable
/// storage. On success its allocation must be released exactly once with
/// hclient_codec_free_buffer, after copying any bytes needed by the caller.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn hclient_codec_decode_image_for_display(
    input: *const u8,
    input_length: usize,
    codec: u32,
    output: *mut CodecBuffer,
) -> i32 {
    if output.is_null() || !(output as usize).is_multiple_of(align_of::<CodecBuffer>()) {
        return CodecError::Argument as i32;
    }
    unsafe {
        output.write(CodecBuffer::default());
    }
    match catch_unwind(AssertUnwindSafe(|| {
        let path = unsafe { path_arg(input, input_length)? };
        decode_image_for_display(path, codec)
    })) {
        Ok(Ok(bytes)) => {
            let owned = bytes.into_boxed_slice();
            let length = owned.len();
            let data = Box::into_raw(owned).cast::<u8>();
            unsafe {
                output.write(CodecBuffer { data, length });
            }
            0
        }
        Ok(Err(error)) => error as i32,
        Err(_) => CodecError::Panic as i32,
    }
}

/// # Safety
/// `data` and `length` must describe an allocation returned by the display call
/// that has not already been freed. A null pointer is accepted as a no-op.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn hclient_codec_free_buffer(data: *mut u8, length: usize) {
    if !data.is_null() {
        unsafe {
            drop(Box::from_raw(std::ptr::slice_from_raw_parts_mut(
                data, length,
            )));
        }
    }
}

unsafe fn path_arg<'a>(pointer: *const u8, length: usize) -> Result<&'a Path, CodecError> {
    if pointer.is_null() || length == 0 {
        return Err(CodecError::Argument);
    }
    let bytes = unsafe { std::slice::from_raw_parts(pointer, length) };
    if bytes.contains(&0) {
        return Err(CodecError::Argument);
    }
    let path = std::str::from_utf8(bytes).map_err(|_| CodecError::Argument)?;
    Ok(Path::new(path))
}

fn valid_result(result: *mut CodecResult) -> bool {
    !result.is_null() && (result as usize).is_multiple_of(align_of::<CodecResult>())
}

unsafe fn invoke(
    result: *mut CodecResult,
    operation: impl FnOnce() -> Result<CodecResult, CodecError>,
) -> i32 {
    if !valid_result(result) {
        return CodecError::Argument as i32;
    }
    unsafe {
        result.write(CodecResult::default());
    }
    match catch_unwind(AssertUnwindSafe(operation)) {
        Ok(Ok(value)) => {
            unsafe {
                result.write(value);
            }
            0
        }
        Ok(Err(error)) => error as i32,
        Err(_) => CodecError::Panic as i32,
    }
}

/// # Safety
/// Every non-null pointer must reference readable/writable storage of its stated
/// length for the call. `result` must point to an aligned CodecResult.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn hclient_codec_encode(
    input: *const u8,
    input_length: usize,
    output: *const u8,
    output_length: usize,
    result: *mut CodecResult,
) -> i32 {
    unsafe {
        invoke(result, || {
            encode_file(
                path_arg(input, input_length)?,
                path_arg(output, output_length)?,
            )
        })
    }
}

/// # Safety
/// Path/result pointers follow encode's contract. Each hash pointer must
/// reference exactly 32 readable bytes for the duration of this call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn hclient_codec_decode(
    input: *const u8,
    input_length: usize,
    output: *const u8,
    output_length: usize,
    codec: u32,
    expected_raw_length: u64,
    expected_raw_hash: *const u8,
    result: *mut CodecResult,
) -> i32 {
    unsafe {
        invoke(result, || {
            if expected_raw_hash.is_null() {
                return Err(CodecError::Argument);
            }
            let raw_hash = expected_raw_hash.cast::<[u8; 32]>().read();
            decode_file(
                path_arg(input, input_length)?,
                path_arg(output, output_length)?,
                codec,
                expected_raw_length,
                raw_hash,
            )
        })
    }
}

/// # Safety
/// Input and hash pointers follow decode's contract. `output` must reference
/// writable storage of `output_length` bytes and must not alias another argument.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn hclient_codec_decode_bytes(
    input: *const u8,
    input_length: usize,
    codec: u32,
    expected_raw_length: u64,
    expected_raw_hash: *const u8,
    output: *mut u8,
    output_length: usize,
    result: *mut CodecResult,
) -> i32 {
    unsafe {
        invoke(result, || {
            if expected_raw_hash.is_null()
                || output.is_null()
                || output_length as u64 != expected_raw_length
            {
                return Err(CodecError::Argument);
            }
            let raw_hash = expected_raw_hash.cast::<[u8; 32]>().read();
            let restored = decode_bytes(
                path_arg(input, input_length)?,
                codec,
                expected_raw_length,
                raw_hash,
            )?;
            std::ptr::copy_nonoverlapping(restored.as_ptr(), output, restored.len());
            Ok(CodecResult::raw(expected_raw_length, raw_hash))
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn raw_identity_and_restore() {
        let directory = tempfile::tempdir().unwrap();
        for (index, data) in [
            include_bytes!("../tests/fixtures/minimal.jpg").as_slice(),
            include_bytes!("../tests/fixtures/minimal.png").as_slice(),
            include_bytes!("../tests/fixtures/passthrough.webp").as_slice(),
            include_bytes!("../tests/fixtures/passthrough.gif").as_slice(),
            include_bytes!("../tests/fixtures/passthrough.avif").as_slice(),
        ]
        .into_iter()
        .enumerate()
        {
            let input = directory.path().join(format!("{index}.raw"));
            let encoded = directory.path().join(format!("{index}.encoded"));
            let restored = directory.path().join(format!("{index}.restored"));
            std::fs::write(&input, data).unwrap();
            let artifact = encode_file(&input, &encoded).unwrap();
            assert!(!encoded.exists());
            assert_eq!(artifact.raw_length, data.len() as u64);
            decode_file(
                &input,
                &restored,
                RAW,
                artifact.raw_length,
                artifact.raw_hash,
            )
            .unwrap();
            assert_eq!(std::fs::read(restored).unwrap(), data);
        }
    }

    #[test]
    fn encoded_page_roundtrips_and_rejects_corruption() {
        let directory = tempfile::tempdir().unwrap();
        for (index, data) in [
            include_bytes!("../tests/fixtures/gradient.jpg").as_slice(),
            include_bytes!("../tests/fixtures/gradient.png").as_slice(),
            include_bytes!("../tests/fixtures/animated.gif").as_slice(),
        ]
        .into_iter()
        .enumerate()
        {
            let input = directory.path().join(format!("{index}.raw"));
            let encoded = directory.path().join(format!("{index}.encoded"));
            let restored = directory.path().join(format!("{index}.restored"));
            std::fs::write(&input, data).unwrap();
            let artifact = encode_file(&input, &encoded).unwrap();
            assert_eq!(artifact.codec, page_codec::PROFILE);
            assert!(artifact.stored_length < artifact.raw_length);
            let object = std::fs::read(&encoded).unwrap();
            assert_eq!(object.len() as u64, artifact.stored_length);
            assert_eq!(
                <[u8; 32]>::from(Sha256::digest(&object)),
                artifact.object_hash
            );
            decode_file(
                &encoded,
                &restored,
                artifact.codec,
                artifact.raw_length,
                artifact.raw_hash,
            )
            .unwrap();
            assert_eq!(std::fs::read(&restored).unwrap(), data);
            let mut buffer = vec![0; artifact.raw_length as usize];
            let mut result = CodecResult::default();
            let input_path = encoded.to_str().unwrap().as_bytes();
            assert_eq!(
                unsafe {
                    hclient_codec_decode_bytes(
                        input_path.as_ptr(),
                        input_path.len(),
                        artifact.codec,
                        artifact.raw_length,
                        artifact.raw_hash.as_ptr(),
                        buffer.as_mut_ptr(),
                        buffer.len(),
                        &mut result,
                    )
                },
                0
            );
            assert_eq!(buffer, std::fs::read(&restored).unwrap());
            assert_eq!(result.raw_hash, artifact.raw_hash);
            // A wrong raw identity leaves caller memory untouched.
            buffer.fill(0x5a);
            assert_eq!(
                unsafe {
                    hclient_codec_decode_bytes(
                        input_path.as_ptr(),
                        input_path.len(),
                        artifact.codec,
                        artifact.raw_length,
                        [0; 32].as_ptr(),
                        buffer.as_mut_ptr(),
                        buffer.len(),
                        &mut result,
                    )
                },
                CodecError::Identity as i32
            );
            assert!(buffer.iter().all(|byte| *byte == 0x5a));
            assert_eq!(
                unsafe {
                    hclient_codec_decode_bytes(
                        input_path.as_ptr(),
                        input_path.len(),
                        artifact.codec,
                        artifact.raw_length,
                        artifact.raw_hash.as_ptr(),
                        buffer.as_mut_ptr(),
                        buffer.len() - 1,
                        &mut result,
                    )
                },
                CodecError::Argument as i32
            );
            std::fs::remove_file(&restored).unwrap();

            // A valid object with the wrong raw identity must not leave a page.
            assert_eq!(
                decode_file(
                    &encoded,
                    &restored,
                    artifact.codec,
                    artifact.raw_length,
                    [0; 32],
                ),
                Err(CodecError::Identity)
            );
            assert!(!restored.exists());

            // Trailing garbage is not a valid zstd stream.
            let mut appended = object.clone();
            appended.push(0);
            std::fs::write(&encoded, &appended).unwrap();
            assert_eq!(
                decode_file(
                    &encoded,
                    &restored,
                    artifact.codec,
                    artifact.raw_length,
                    artifact.raw_hash,
                ),
                Err(CodecError::Identity)
            );
            assert!(!restored.exists());

            // Corrupt encoded bytes cannot produce a restored page.
            let mut corrupt = object;
            corrupt[0] ^= 1;
            std::fs::write(&encoded, corrupt).unwrap();
            assert_eq!(
                decode_file(
                    &encoded,
                    &restored,
                    artifact.codec,
                    artifact.raw_length,
                    artifact.raw_hash,
                ),
                Err(CodecError::Identity)
            );
            assert!(!restored.exists());
        }
    }

    #[test]
    fn failed_identity_removes_only_owned_output() {
        let directory = tempfile::tempdir().unwrap();
        let input = directory.path().join("input");
        let output = directory.path().join("output");
        std::fs::write(&input, b"payload").unwrap();
        assert_eq!(
            decode_file(&input, &output, RAW, 7, [0; 32]),
            Err(CodecError::Identity)
        );
        assert!(!output.exists());
        std::fs::write(&output, b"preserve").unwrap();
        assert_eq!(
            decode_file(&input, &output, RAW, 7, [0; 32]),
            Err(CodecError::Io)
        );
        assert_eq!(std::fs::read(output).unwrap(), b"preserve");
    }

    #[test]
    fn legacy_png_does_not_reconstruct_on_display_path() {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("legacy.pcf");
        let png = include_bytes!("../tests/fixtures/gradient.png");
        let pcf = precomp2::encode_bytes(png, &precomp2::EncodeConfig::default()).unwrap();
        let object = zstd::stream::encode_all(pcf.as_slice(), 6).unwrap();
        std::fs::write(&path, object).unwrap();
        assert_eq!(
            decode_image_for_display(&path, page_codec::PROFILE),
            Err(CodecError::UnsupportedProfile)
        );
        assert_eq!(
            decode_bytes(
                &path,
                page_codec::PROFILE,
                png.len() as u64,
                Sha256::digest(png).into()
            )
            .unwrap(),
            png
        );
    }

    #[test]
    fn owned_display_buffers_and_failures() {
        let directory = tempfile::tempdir().unwrap();
        for (name, bytes) in [
            (
                "png",
                include_bytes!("../tests/fixtures/gradient.png").as_slice(),
            ),
            (
                "jpg",
                include_bytes!("../tests/fixtures/gradient.jpg").as_slice(),
            ),
            (
                "gif",
                include_bytes!("../tests/fixtures/animated.gif").as_slice(),
            ),
            (
                "webp",
                include_bytes!("../tests/fixtures/passthrough.webp").as_slice(),
            ),
        ] {
            let source = directory.path().join(name);
            let target = directory.path().join(format!("{name}.pcf"));
            std::fs::write(&source, bytes).unwrap();
            let artifact = encode_file(&source, &target).unwrap();
            let path = if artifact.codec == RAW {
                &source
            } else {
                &target
            };
            let path = path.to_str().unwrap().as_bytes();
            let mut output = CodecBuffer::default();
            assert_eq!(
                unsafe {
                    hclient_codec_decode_image_for_display(
                        path.as_ptr(),
                        path.len(),
                        artifact.codec,
                        &mut output,
                    )
                },
                0
            );
            assert!(!output.data.is_null());
            let display =
                unsafe { std::slice::from_raw_parts(output.data, output.length).to_vec() };
            unsafe {
                hclient_codec_free_buffer(output.data, output.length);
            }
            if name == "png" {
                assert_ne!(display, bytes);
                assert_eq!(&display[8..12], b"WEBP");
            } else {
                assert_eq!(display, bytes);
            }
            // Caller bytes survive the Rust allocation's release.
            assert!(!display.is_empty());
            std::fs::write(
                if artifact.codec == RAW {
                    &source
                } else {
                    &target
                },
                b"corrupt",
            )
            .unwrap();
            if artifact.codec != RAW {
                assert_eq!(
                    unsafe {
                        hclient_codec_decode_image_for_display(
                            path.as_ptr(),
                            path.len(),
                            artifact.codec,
                            &mut output,
                        )
                    },
                    CodecError::Identity as i32
                );
                assert!(output.data.is_null());
                assert_eq!(output.length, 0);
            }
        }
        let mut output = CodecBuffer::default();
        assert_eq!(
            unsafe {
                hclient_codec_decode_image_for_display(std::ptr::null(), 0, RAW, &mut output)
            },
            CodecError::Argument as i32
        );
        assert!(output.data.is_null());
        unsafe {
            hclient_codec_free_buffer(output.data, output.length);
        }
    }

    #[test]
    fn ffi_rejects_null_arguments() {
        let mut result = CodecResult::default();
        unsafe {
            assert_eq!(
                hclient_codec_encode(std::ptr::null(), 0, std::ptr::null(), 0, &mut result),
                1
            );
            assert_eq!(
                hclient_codec_encode(
                    std::ptr::null(),
                    0,
                    std::ptr::null(),
                    0,
                    std::ptr::null_mut()
                ),
                1
            );
        }
    }
}
