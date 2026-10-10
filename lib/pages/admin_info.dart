import 'package:flutter/material.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class AdminInfoPage extends StatefulWidget {
  const AdminInfoPage({super.key});
  @override
  State<AdminInfoPage> createState() => _AdminInfoPageState();
}

class _AdminInfoPageState extends State<AdminInfoPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _items = await Api.infoSemua();
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _form([Map<String, dynamic>? item]) async {
    final kategori = ValueNotifier<String>('${item?['kategori'] ?? 'fakta'}');
    final judul = TextEditingController(text: '${item?['judul'] ?? ''}');
    final isi = TextEditingController(text: '${item?['isi'] ?? ''}');
    final aktif = ValueNotifier<bool>(item?['aktif'] as bool? ?? true);
    final key = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'Tambah info' : 'Edit info'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 6),
                ValueListenableBuilder<String>(
                  valueListenable: kategori,
                  builder: (_, v, __) => DropdownButtonFormField<String>(
                    initialValue: v,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: const [
                      DropdownMenuItem(value: 'fakta', child: Text('Fakta Unik')),
                      DropdownMenuItem(value: 'info', child: Text('Info Penting')),
                      DropdownMenuItem(value: 'tips', child: Text('Tips')),
                    ],
                    onChanged: (x) => kategori.value = x ?? 'fakta',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: judul, decoration: const InputDecoration(labelText: 'Judul'), validator: (v) => requiredValidator(v, 'Judul')),
                const SizedBox(height: 12),
                TextFormField(
                  controller: isi,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Isi'),
                  validator: (v) => requiredValidator(v, 'Isi'),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: aktif,
                  builder: (_, v, __) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tampilkan di dashboard'),
                    value: v,
                    onChanged: (x) => aktif.value = x,
                  ),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    final data = {'kategori': kategori.value, 'judul': judul.text.trim(), 'isi': isi.text.trim(), 'aktif': aktif.value};
    if (ok != true) return;
    try {
      await Api.saveInfo(data, id: item?['id'] as int?);
      await _load();
      if (mounted) toast(context, 'Info disimpan');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await confirmDialog(context, 'Hapus info?', '"${item['judul']}" akan dihapus.', okText: 'Hapus', danger: true);
    if (!ok) return;
    try {
      await Api.deleteInfo(item['id'] as int);
      await _load();
      if (mounted) toast(context, 'Info dihapus');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
  }

  String _label(String k) => k == 'fakta' ? 'Fakta Unik' : (k == 'tips' ? 'Tips' : 'Info Penting');

  @override
  Widget build(BuildContext context) {
    return PageWrap(
      title: 'Kelola Info Pisang',
      subtitle: 'Konten fakta, info, dan tips yang tampil di dashboard pengguna.',
      trailing: ElevatedButton.icon(onPressed: () => _form(), icon: const Icon(Icons.add_rounded), label: const Text('Tambah')),
      children: [
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (_items.isEmpty)
          const AppCard(child: Text('Belum ada konten. Tekan "Tambah".'))
        else
          ResponsiveWrap(minWidth: 420, children: [
            for (final i in _items)
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                      backgroundColor: alpha(kAmber, .2),
                      label: Text(_label('${i['kategori']}'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    if (i['aktif'] != true)
                      Chip(visualDensity: VisualDensity.compact, side: BorderSide.none, backgroundColor: Colors.grey.shade300, label: const Text('Nonaktif', style: TextStyle(fontSize: 12))),
                    const Spacer(),
                    IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_rounded, size: 20), onPressed: () => _form(i)),
                    IconButton(tooltip: 'Hapus', icon: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red.shade600), onPressed: () => _delete(i)),
                  ]),
                  Text('${i['judul']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kBrown)),
                  const SizedBox(height: 6),
                  Text('${i['isi']}', style: TextStyle(color: Colors.brown.shade400, height: 1.4)),
                ]),
              ),
          ]),
      ],
    );
  }
}
