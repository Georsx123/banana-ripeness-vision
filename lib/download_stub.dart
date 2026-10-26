import 'dart:typed_data';

/// Cadangan untuk platform yang tidak dikenal.
Future<void> saveBytesFile(String filename, Uint8List bytes, String mime) async {
  throw UnsupportedError('Ekspor belum didukung di platform ini.');
}
