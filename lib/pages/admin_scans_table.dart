import 'package:flutter/material.dart';
import '../download.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import '../xlsx.dart';
import 'package:flutter/foundation.dart';

/// Tabel riwayat scan SELURUH pengguna (tabel riwayat_scan di database), khusus admin.
/// Data sama dengan riwayat tiap pengguna: kalau pengguna menghapus riwayatnya, baris ini ikut hilang.
/// Sengaja tanpa tombol bersihkan agar riwayat semua pengguna tidak terhapus tidak sengaja.
class AdminScansTable extends StatefulWidget {
  const AdminScansTable({super.key});
  @override
  State<AdminScansTable> createState() => _AdminScansTableState();
}

class _AdminScansTableState extends State<AdminScansTable> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  int _perPage = 10;
  int _page = 0;
  String _q = '';
  String _fKelas = '';
  String _fMode = '';
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _rows = await Api.allScans();
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  String _nama(Map<String, dynamic> r) => r['profiles'] is Map ? '${(r['profiles'] as Map)['nama']}' : '-';
  String _uname(Map<String, dynamic> r) => r['profiles'] is Map ? '${(r['profiles'] as Map)['username']}' : '-';

  List<Map<String, dynamic>> get _view {
    final q = _q.trim().toLowerCase();
    return _rows.where((s) {
      final k = infoKelas('${s['kelas']}');
      final t = DateTime.tryParse('${s['created_at']}');
      if (_fKelas.isNotEmpty && k.key != _fKelas) return false;
      if (_fMode.isNotEmpty && s['mode'] != _fMode) return false;
      if (t != null && !inDateRange(t, _range)) return false;
      if (q.isNotEmpty) {
        final hay = '${_nama(s)} ${_uname(s)} ${k.nama} ${s['mode']}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _resetFilters() => setState(() {
        _q = '';
        _fKelas = '';
        _fMode = '';
        _range = null;
        _page = 0;
      });

  Future<void> _export() async {
    final view = _view;
    if (view.isEmpty) {
      toast(context, 'Tidak ada data untuk diekspor.', error: true);
      return;
    }
    final now = DateTime.now();
    final name = 'riwayat_semua_user_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.xlsx';
    try {
      final bytes = buildXlsx(
        sheetName: 'Riwayat Semua User',
        headers: const ['No', 'Waktu scan', 'Nama', 'Username', 'Mode', 'Kelas', 'Jumlah pisang', 'Akurasi rata-rata (%)'],
        widths: const [6, 20, 26, 20, 12, 22, 15, 22],
        centerCols: const [0, 4, 6],
        rows: [
          for (var i = 0; i < view.length; i++)
            <Object?>[
              i + 1,
              DateTime.tryParse('${view[i]['created_at']}'),
              _nama(view[i]),
              _uname(view[i]),
              view[i]['mode'] == 'realtime' ? 'Realtime' : 'Gambar',
              infoKelas('${view[i]['kelas']}').nama,
              (view[i]['jumlah_objek'] as num?)?.toInt() ?? 1,
              double.parse((view[i]['akurasi'] as num).toStringAsFixed(1)),
            ],
        ],
      );
      await saveBytesFile(name, bytes, xlsxMime);
      if (mounted && kIsWeb) toast(context, 'File $name diunduh');
    } catch (e) {
      if (mounted) toast(context, 'Gagal mengekspor: ${Api.friendly(e)}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final pages = view.isEmpty ? 1 : (view.length + _perPage - 1) ~/ _perPage;
    final page = _page.clamp(0, pages - 1).toInt();
    final start = page * _perPage;
    final end = start + _perPage > view.length ? view.length : start + _perPage;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.download_rounded), label: const Text('Ekspor Excel')),
        OutlinedButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Muat ulang')),
        Text(
          _loading ? 'Memuat...' : '${view.length} dari ${_rows.length} catatan (maksimal 5000 terbaru)',
          style: TextStyle(color: Colors.brown.shade400, fontSize: 12.5),
        ),
      ]),
      const SizedBox(height: 12),
      FilterBar(
        hint: 'Cari nama, username, kelas, atau mode',
        onSearch: (v) => setState(() {
          _q = v;
          _page = 0;
        }),
        filters: [
          FilterDrop(
            label: 'Kelas',
            value: _fKelas,
            options: [const FOpt('', 'Semua kelas'), for (final k in kelasList) FOpt(k.key, k.nama)],
            onChanged: (v) => setState(() {
              _fKelas = v;
              _page = 0;
            }),
          ),
          FilterDrop(
            label: 'Mode',
            value: _fMode,
            options: const [FOpt('', 'Semua mode'), FOpt('gambar', 'Gambar'), FOpt('realtime', 'Realtime')],
            onChanged: (v) => setState(() {
              _fMode = v;
              _page = 0;
            }),
          ),
        ],
        range: _range,
        onRange: (r) => setState(() {
          _range = r;
          _page = 0;
        }),
        onReset: _resetFilters,
      ),
      const SizedBox(height: 12),
      if (_loading)
        const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
      else
        AppCard(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            if (view.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Text('Tidak ada data yang sesuai pencarian atau filter.'))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width > 1000 ? 900 : 700),
                  child: DataTable(
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('No')),
                      DataColumn(label: Text('Waktu scan')),
                      DataColumn(label: Text('Pengguna')),
                      DataColumn(label: Text('Mode')),
                      DataColumn(label: Text('Kelas')),
                      DataColumn(label: Text('Jumlah pisang')),
                      DataColumn(label: Text('Akurasi rata-rata')),
                    ],
                    rows: [
                      for (var i = start; i < end; i++)
                        DataRow(cells: [
                          DataCell(Text('${i + 1}')),
                          DataCell(Text(fmtDate(DateTime.parse('${view[i]['created_at']}')))),
                          DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_nama(view[i]), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('@${_uname(view[i])}', style: TextStyle(fontSize: 11.5, color: Colors.brown.shade400)),
                          ])),
                          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(view[i]['mode'] == 'realtime' ? Icons.videocam_rounded : Icons.image_rounded, size: 16, color: kBrown),
                            const SizedBox(width: 6),
                            Text(view[i]['mode'] == 'realtime' ? 'Realtime' : 'Gambar'),
                          ])),
                          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 11, height: 11, decoration: BoxDecoration(color: infoKelas('${view[i]['kelas']}').warna, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(infoKelas('${view[i]['kelas']}').nama, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ])),
                          DataCell(Text('${view[i]['jumlah_objek']}')),
                          DataCell(Text('${(view[i]['akurasi'] as num).toStringAsFixed(1)}%')),
                        ]),
                    ],
                  ),
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
              child: PagerBar(
                total: view.length,
                page: page,
                perPage: _perPage,
                perPageOptions: const [10, 25, 50, 100],
                onPage: (p) => setState(() => _page = p),
                onPerPage: (v) => setState(() {
                  _perPage = v;
                  _page = 0;
                }),
              ),
            ),
          ]),
        ),
    ]);
  }
}
