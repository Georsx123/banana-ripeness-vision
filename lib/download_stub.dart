import 'dart:typed_data';

/// Platform non-web (mis. APK) belum mendukung unduh file langsung.
void saveBytesFile(String filename, Uint8List bytes, String mime) {
  throw UnsupportedError('Ekspor belum didukung di platform ini.');
}
