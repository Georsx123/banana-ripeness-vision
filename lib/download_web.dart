import 'dart:convert';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Memicu unduhan berkas di browser.
Future<void> saveBytesFile(String filename, Uint8List bytes, String mime) async {
  final a = web.document.createElement('a') as web.HTMLAnchorElement;
  a.href = 'data:$mime;base64,${base64Encode(bytes)}';
  a.download = filename;
  a.style.display = 'none';
  web.document.body!.appendChild(a);
  a.click();
  a.remove();
}
