import 'package:flutter/material.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

/// Pengaturan admin: mode pemeliharaan (mematikan fitur scan untuk semua pengguna).
class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});
  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _msg = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _on = false;
  bool _savedOn = false; // kondisi yang sudah tersimpan di server

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final m = await Api.maintenance();
      _on = m.on;
      _savedOn = m.on;
      _msg.text = m.message;
    } catch (e) {
      if (mounted) toast(context, 'Gagal memuat pengaturan. Pastikan SQL tambahan sudah dijalankan.', error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_on && !_savedOn) {
      final ok = await confirmDialog(
        context,
        'Aktifkan mode pemeliharaan?',
        'Semua pengguna (termasuk kamu) tidak akan bisa scan, baik input gambar maupun realtime, sampai mode ini dimatikan.',
        okText: 'Aktifkan',
        danger: true,
      );
      if (!ok) return;
    }
    setState(() => _saving = true);
    try {
      final msg = _msg.text.trim().isEmpty ? MaintState.defaultMessage : _msg.text.trim();
      await Api.setMaintenance(_on, msg);
      _msg.text = msg;
      _savedOn = _on;
      if (mounted) toast(context, _on ? 'Mode pemeliharaan AKTIF. Scan dimatikan.' : 'Mode pemeliharaan nonaktif. Scan berjalan normal.');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageWrap(
      title: 'Pengaturan',
      subtitle: 'Pengaturan aplikasi khusus admin.',
      children: [
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: alpha(kAmber, .2), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.construction_rounded, color: kDeepAmber),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Mode pemeliharaan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBrown))),
                Chip(
                  side: BorderSide.none,
                  backgroundColor: _savedOn ? Colors.red.shade100 : Colors.green.shade100,
                  label: Text(_savedOn ? 'Scan DIMATIKAN' : 'Scan aktif', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 12),
              Text(
                'Saat aktif, fitur scan tidak bisa dipakai oleh siapa pun (input gambar maupun realtime), dan pengguna melihat pesan di bawah. '
                'Menu lain tetap berjalan. Berguna untuk melindungi jatah Roboflow setelah presentasi.',
                style: TextStyle(color: Colors.brown.shade500, height: 1.4),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _on,
                onChanged: (v) => setState(() => _on = v),
                title: Text(_on ? 'Aktif: scan dimatikan' : 'Nonaktif: scan berjalan normal', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _msg,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Pesan untuk pengguna'),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: AppButton(label: 'Simpan Pengaturan', icon: Icons.save_rounded, loading: _saving, onPressed: _save)),
            ]),
          ),
      ],
    );
  }
}
