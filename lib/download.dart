// Pemilih implementasi unduh file sesuai platform.
// Web  -> download_web.dart
// Lain -> download_stub.dart (belum didukung)
export 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
