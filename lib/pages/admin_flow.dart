import 'package:flutter/material.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

/// Aksi sensitif admin butuh izin dari 1 admin lain.
/// - Jika sudah ada izin yang disetujui dan masih berlaku: mengembalikan id izin (silakan jalankan aksinya).
/// - Jika belum: menampilkan form permintaan (alasan wajib). Permintaan otomatis masuk ke menu Pesan,
///   lalu fungsi ini mengembalikan null. Setelah disetujui, ulangi aksinya.
/// Izin hanya berlaku sekali dan 1 jam setelah disetujui.
Future<int?> requireApproval(
  BuildContext context, {
  required String jenis,
  String? targetId,
  required String label,
  required String judul,
  required String detail,
}) async {
  try {
    final grant = await Api.myGrant(jenis, targetId);
    if (grant != null) return grant;
    if (await Api.myPending(jenis, targetId)) {
      if (context.mounted) {
        toast(context, 'Permintaanmu masih menunggu persetujuan admin lain. Cek menu Pesan.', error: true);
      }
      return null;
    }
    if (!context.mounted) return null;
    final alasan = await showDialog<String>(context: context, builder: (_) => _RequestDialog(judul: judul, detail: detail));
    if (alasan == null || !context.mounted) return null;
    await Api.requestAction(jenis: jenis, targetId: targetId, label: label, detail: detail, alasan: alasan);
    if (context.mounted) {
      toast(context, 'Permintaan dikirim ke menu Pesan. Setelah admin lain menyetujui, ulangi aksinya.');
    }
  } catch (e) {
    if (context.mounted) toast(context, Api.friendly(e), error: true);
  }
  return null;
}

class _RequestDialog extends StatefulWidget {
  final String judul;
  final String detail;
  const _RequestDialog({required this.judul, required this.detail});
  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _key = GlobalKey<FormState>();
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Butuh izin: ${widget.judul}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: alpha(kAmber, .15), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  'Aksi ini harus disetujui 1 admin lain. Permintaanmu otomatis masuk ke menu Pesan. '
                  'Setelah disetujui, kamu bisa melakukan aksinya satu kali (berlaku 1 jam).',
                  style: TextStyle(color: Colors.brown.shade700, fontSize: 12.5, height: 1.35),
                ),
              ),
              const SizedBox(height: 12),
              Text(widget.detail, style: const TextStyle(fontWeight: FontWeight.w800, color: kBrown)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Alasan (wajib diisi)', alignLabelWithHint: true),
                validator: (v) => (v ?? '').trim().length < 3 ? 'Alasan wajib diisi' : null,
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(140, 44)),
          onPressed: () {
            if (_key.currentState!.validate()) Navigator.pop(context, _c.text.trim());
          },
          child: const Text('Kirim Permintaan'),
        ),
      ],
    );
  }
}
