/// Facts from the encoded input already consumed by the image provider.
/// Dimensions describe the source, even when Flutter decodes a smaller image.
class ImageSourceInfo {
  final int encodedLength;
  final String? mime;
  final int? width;
  final int? height;

  const ImageSourceInfo({
    required this.encodedLength,
    this.mime,
    this.width,
    this.height,
  });

  @override
  bool operator ==(Object other) =>
      other is ImageSourceInfo &&
      encodedLength == other.encodedLength &&
      mime == other.mime &&
      width == other.width &&
      height == other.height;

  @override
  int get hashCode => Object.hash(encodedLength, mime, width, height);
}
