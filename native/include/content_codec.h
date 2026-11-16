#ifndef HCLIENT_CONTENT_CODEC_H
#define HCLIENT_CONTENT_CODEC_H
#include <stddef.h>
#include <stdint.h>

/* UTF-8 paths are length delimited and cannot contain NUL. The caller owns all
 * argument/result memory. Display buffers are allocated by Rust and released
 * with hclient_codec_free_buffer after the caller copies them.
 * Calls are synchronous. Dart dispatches conversions and display reads on
 * separate persistent worker isolates.
 * Status: 0 success, 1 invalid argument, 2 I/O, 3 identity mismatch,
 * 4 unsupported profile, 5 internal panic. No diagnostic contains input data.
 */
typedef struct HclientCodecResult {
  uint32_t codec; /* 0 = raw; 1 = hclient-pcf2-zstd-v1 */
  uint64_t raw_length;
  uint64_t stored_length;
  uint8_t raw_hash[32];
  uint8_t object_hash[32];
} HclientCodecResult;

int32_t hclient_codec_encode(
  const uint8_t *input, size_t input_length,
  const uint8_t *output, size_t output_length,
  HclientCodecResult *result);
/* Output must not exist. It is deleted on failure. The raw hash contains exactly
 * 32 bytes. The output must match its declared raw identity. */
int32_t hclient_codec_decode(
  const uint8_t *input, size_t input_length,
  const uint8_t *output, size_t output_length, uint32_t codec,
  uint64_t expected_raw_length, const uint8_t *expected_raw_hash,
  HclientCodecResult *result);
/* Decodes into caller-owned storage, which must have exactly raw_length bytes.
 * No output bytes are committed before decoded identity validation succeeds. */
int32_t hclient_codec_decode_bytes(
  const uint8_t *input, size_t input_length, uint32_t codec,
  uint64_t expected_raw_length, const uint8_t *expected_raw_hash,
  uint8_t *output, size_t output_length, HclientCodecResult *result);
/* Display bytes preserve image semantics, not original file identity. There is
 * no raw-hash verification on this read path. Unsupported PNG carriers fail. */
typedef struct HclientCodecBuffer {
  uint8_t *data;
  size_t length;
} HclientCodecBuffer;
int32_t hclient_codec_decode_image_for_display(
  const uint8_t *input, size_t input_length, uint32_t codec,
  HclientCodecBuffer *output);
void hclient_codec_free_buffer(uint8_t *data, size_t length);
#endif
