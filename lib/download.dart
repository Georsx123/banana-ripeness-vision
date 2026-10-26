// Pemilih implementasi unduh/simpan berkas sesuai platform.
// Web              -> download_web.dart (unduhan browser)
// Android/iOS/dll. -> download_io.dart  (menu "bagikan": simpan ke berkas, Drive, WhatsApp, dll)
export 'download_stub.dart'
    if (dart.library.js_interop) 'download_web.dart'
    if (dart.library.io) 'download_io.dart';
