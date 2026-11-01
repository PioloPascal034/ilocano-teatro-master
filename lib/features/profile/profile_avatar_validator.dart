import 'dart:typed_data';

enum ProfileAvatarFormat {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  webp('image/webp', 'webp');

  const ProfileAvatarFormat(this.mimeType, this.extension);

  final String mimeType;
  final String extension;
}

abstract final class ProfileAvatarValidator {
  static const maxBytes = 5 * 1024 * 1024;

  static ProfileAvatarFormat validate(Uint8List bytes) {
    if (bytes.isEmpty) throw const FormatException('Choose a non-empty image.');
    if (bytes.lengthInBytes > maxBytes) {
      throw const FormatException('Images must be 5 MiB or smaller.');
    }
    if (_isJpeg(bytes)) return ProfileAvatarFormat.jpeg;
    if (_isPng(bytes)) return ProfileAvatarFormat.png;
    if (_isWebp(bytes)) return ProfileAvatarFormat.webp;
    throw const FormatException('Choose a JPEG, PNG, or WebP image.');
  }

  static bool _isJpeg(Uint8List bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;

  static bool _isPng(Uint8List bytes) =>
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a;

  static bool _isWebp(Uint8List bytes) =>
      bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
}
