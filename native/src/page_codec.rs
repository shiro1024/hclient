use super::{CodecError, CodecResult, IO_BUFFER_SIZE, OutputFile, open_input};
use sha2::{Digest, Sha256};
use std::{
    io::{Read, Write},
    path::Path,
};

pub(super) const PROFILE: u32 = 1;

fn is_candidate(bytes: &[u8]) -> bool {
    bytes.starts_with(b"\xff\xd8")
        || bytes.starts_with(b"\x89PNG\r\n\x1a\n")
        || bytes.starts_with(b"GIF87a")
        || bytes.starts_with(b"GIF89a")
}

pub(super) fn encode(input: &Path, output: &Path) -> Result<CodecResult, CodecError> {
    let mut reader = open_input(input)?;
    let mut hash = Sha256::new();
    let mut length = 0u64;
    let mut source: Option<Vec<u8>> = None;
    let mut buffer = [0u8; IO_BUFFER_SIZE];
    loop {
        let count = reader.read(&mut buffer)?;
        if count == 0 {
            break;
        }
        if length == 0 && is_candidate(&buffer[..count]) {
            source = Some(Vec::new());
        }
        length = length
            .checked_add(count as u64)
            .ok_or(CodecError::Identity)?;
        hash.update(&buffer[..count]);
        if let Some(source) = source.as_mut() {
            source.extend_from_slice(&buffer[..count]);
        }
    }
    let raw = CodecResult::raw(length, hash.finalize().into());
    let Some(source) = source else {
        return Ok(raw);
    };
    let config = precomp2::EncodeConfig {
        enable_png_webp: true,
        ..Default::default()
    };
    let pcf = match precomp2::encode_bytes(&source, &config) {
        Ok(pcf) => pcf,
        Err(_) => return Ok(raw),
    };
    if source.starts_with(b"\x89PNG\r\n\x1a\n") {
        let display = precomp2::decode_image_for_display(&pcf, &precomp2::DecodeConfig::default());
        if !matches!(display, Ok(Some(bytes)) if bytes.starts_with(b"RIFF") && bytes.get(8..12) == Some(b"WEBP"))
        {
            return Ok(raw);
        }
    }
    let level = if source.starts_with(b"\x89PNG\r\n\x1a\n") {
        6
    } else if source.starts_with(b"GIF") {
        9
    } else {
        3
    };
    let mut encoder = zstd::stream::write::Encoder::new(Vec::new(), level)?;
    encoder.write_all(&pcf)?;
    let stored = encoder.finish()?;
    if stored.len() as u64 >= length {
        return Ok(raw);
    }
    let stored_length = stored.len() as u64;
    let object_hash = Sha256::digest(&stored).into();
    let mut destination = OutputFile::create(output)?;
    destination
        .file
        .as_mut()
        .ok_or(CodecError::Io)?
        .write_all(&stored)?;
    destination.finish();
    Ok(CodecResult {
        codec: PROFILE,
        stored_length,
        object_hash,
        ..raw
    })
}

pub(super) fn decode_bytes(
    input: &Path,
    raw_length: u64,
    raw_hash: [u8; 32],
) -> Result<Vec<u8>, CodecError> {
    let mut object = Vec::new();
    open_input(input)?.read_to_end(&mut object)?;
    let pcf = zstd::stream::decode_all(object.as_slice()).map_err(|_| CodecError::Identity)?;
    let config = precomp2::DecodeConfig::default();
    let restored = precomp2::decode_bytes(&pcf, &config).map_err(|_| CodecError::Identity)?;
    if restored.len() as u64 != raw_length
        || <[u8; 32]>::from(Sha256::digest(&restored)) != raw_hash
    {
        return Err(CodecError::Identity);
    }
    Ok(restored)
}

pub(super) fn decode_image_for_display(input: &Path) -> Result<Vec<u8>, CodecError> {
    let mut object = Vec::new();
    open_input(input)?.read_to_end(&mut object)?;
    let pcf = zstd::stream::decode_all(object.as_slice()).map_err(|_| CodecError::Identity)?;
    precomp2::decode_image_for_display(&pcf, &precomp2::DecodeConfig::default())
        .map_err(|_| CodecError::Identity)?
        .ok_or(CodecError::UnsupportedProfile)
}
