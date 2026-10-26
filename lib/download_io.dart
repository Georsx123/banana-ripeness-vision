import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Android/iOS: simpan ke folder sementara, lalu buka menu "bagikan" bawaan HP
/// (pilih Simpan ke berkas/Drive, WhatsApp, Excel, dan lain-lain).
Future<void> saveBytesFile(String filename, Uint8List bytes, String mime) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: mime, name: filename)], subject: filename),
  );
}
