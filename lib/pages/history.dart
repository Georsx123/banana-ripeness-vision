import 'package:flutter/material.dart';
import '../charts.dart';
import '../download.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import '../xlsx.dart';
import 'package:flutter/foundation.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _scans = [];
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
    try {
      _scans = await Api.myScans();
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Baris yang lolos pencarian dan filter.
  List<Map<String, dynamic>> get _view {
    final q = _q.trim().toLowerCase();
    return _scans.where((s) {
      final k = infoKelas('${s['kelas']}');
      final t = DateTime.tryParse('${s['created_at']}');
      if (_fKelas.isNotEmpty && k.key != _fKelas) return false;
      if (_fMode.isNotEmpty && s['mode'] != _fMode) return false;
      if (t != null && !inDateRange(t, _range)) return false;
      if (q.isNotEmpty) {
        final hay = '${k.nama} ${k.key} ${s['mode']} ${t == null ? '' : fmtDate(t)}'.toLowerCase();
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

  /// Mengunduh riwayat yang sedang tampil (sesuai filter) sebagai berkas Excel (.xlsx).
  Future<void> _exportExcel() async {
    final view = _view;
    if (view.isEmpty) {
      toast(context, 'Tidak ada data untuk diekspor.', error: true);
      return;
    }
    final rows = <List<Object?>>[];
    for (var i = 0; i < view.length; i++) {
      final s = view[i];
      rows.add([
        i + 1,
        DateTime.tryParse('${s['created_at']}'),
        s['mode'] == 'realtime' ? 'Realtime' : 'Gambar',
        infoKelas('${s['kelas']}').nama,
        (s['jumlah_objek'] as num?)?.toInt() ?? 1,
        double.parse((s['akurasi'] as num).toStringAsFixed(1)),
      ]);
    }
    final now = DateTime.now();
    final name = 'riwayat_scan_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.xlsx';
    try {
      final bytes = buildXlsx(
        sheetName: 'Riwayat Scan',
        headers: const ['No', 'Waktu scan', 'Mode', 'Kelas', 'Jumlah pisang', 'Akurasi rata-rata (%)'],
        widths: const [6, 20, 12, 22, 15, 22],
        centerCols: const [0, 2, 4],
        rows: rows,
      );
      await saveBytesFile(name, bytes, xlsxMime);
      if (mounted && kIsWeb) toast(context, 'File $name diunduh');
    } catch (e) {
      if (mounted) toast(context, 'Gagal mengekspor: ${Api.friendly(e)}', error: true);
    }
  }

  Future<void> _clearAll() async {
    final ok = await confirmDialog(
      context,
      'Hapus semua riwayat?',
      'Seluruh riwayat scan kamu akan dihapus permanen dan tidak bisa dikembalikan. Ekspor ke Excel dulu kalau ingin menyimpan salinannya.',
      okText: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.clearMyScans();
      if (!mounted) return;
      setState(() => _scans = []);
      toast(context, 'Riwayat dihapus');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
  }

  Future<void> _deleteOne(Map<String, dynamic> s) async {
    final k = infoKelas('${s['kelas']}');
    final t = DateTime.tryParse('${s['created_at']}');
    final ok = await confirmDialog(
      context,
      'Hapus riwayat ini?',
      'Catatan "${k.nama}" (${s['jumlah_objek']} pisang)${t == null ? '' : ' pada ${fmtDate(t)}'} akan dihapus permanen.',
      okText: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.deleteScan(s['id'] as int);
      if (!mounted) return;
      setState(() => _scans.removeWhere((e) => e['id'] == s['id']));
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = classCounts(_scans);
    // 7 hari terakhir
    final now = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day).subtract(Duration(days: i))];
    final perDay = days.map((d) {
      return distinctScans(_scans.where((s) {
        final t = DateTime.tryParse('${s['created_at']}')?.toLocal();
        return t != null && t.year == d.year && t.month == d.month && t.day == d.day;
      })).toDouble();
    }).toList();

    double avg = 0;
    if (_scans.isNotEmpty) {
      avg = _scans.map((s) => (s['akurasi'] as num).toDouble()).reduce((a, b) => a + b) / _scans.length;
    }

    final view = _view;
    final pages = view.isEmpty ? 1 : (view.length + _perPage - 1) ~/ _perPage;
    final page = _page.clamp(0, pages - 1).toInt();
    final start = page * _perPage;
    final end = start + _perPage > view.length ? view.length : start + _perPage;

    return PageWrap(
      title: 'Riwayat Scan',
      subtitle: 'Catatan semua hasil scan kamu.',
      children: [
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (_scans.isEmpty)
          const AppCard(
            padding: EdgeInsets.symmetric(vertical: 50, horizontal: 20),
            child: Column(children: [
              BananaImage(size: 56),
              SizedBox(height: 10),
              Text('Belum ada riwayat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kBrown)),
              SizedBox(height: 4),
              Text('Hasil scan yang kamu simpan akan muncul di sini.'),
            ]),
          )
        else ...[
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton.icon(onPressed: _exportExcel, icon: const Icon(Icons.download_rounded), label: const Text('Ekspor Excel')),
            OutlinedButton.icon(
              onPressed: _clearAll,
              icon: Icon(Icons.delete_sweep_rounded, color: Colors.red.shade700),
              label: Text('Hapus Semua', style: TextStyle(color: Colors.red.shade700)),
            ),
          ]),
          const SizedBox(height: 14),
          ResponsiveWrap(minWidth: 230, children: [
            StatCard(icon: Icons.qr_code_scanner_rounded, label: 'Total scan', value: '${distinctScans(_scans)}', color: kDeepAmber),
            StatCard(icon: Icons.verified_rounded, label: 'Rata-rata akurasi', value: '${avg.toStringAsFixed(1)}%', color: kGreen),
            StatCard(
                icon: Icons.videocam_rounded,
                label: 'Scan realtime',
                value: '${distinctScans(_scans.where((s) => s['mode'] == 'realtime'))}',
                color: const Color(0xFF8E24AA)),
          ]),
          const SizedBox(height: 16),
          ResponsiveWrap(minWidth: 420, children: [
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Pisang terdeteksi per kelas', style: TextStyle(fontWeight: FontWeight.w800, color: kBrown)),
                const SizedBox(height: 14),
                ClassBarChart(counts: counts),
              ]),
            ),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Aktivitas 7 hari terakhir', style: TextStyle(fontWeight: FontWeight.w800, color: kBrown)),
                const SizedBox(height: 14),
                SimpleBarChart(
                  labels: [for (final d in days) '${two(d.day)}/${two(d.month)}'],
                  values: perDay,
                  colors: const [kDeepAmber],
                ),
              ]),
            ),
          ]),
          const SectionTitle('Tabel riwayat', Icons.table_rows_rounded),
          FilterBar(
            hint: 'Cari kelas, mode, atau tanggal',
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
          AppCard(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              if (view.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Text('Tidak ada data yang sesuai pencarian atau filter.'))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width > 1000 ? 900 : 640),
                    child: DataTable(
                      columnSpacing: 26,
                      columns: const [
                        DataColumn(label: Text('No')),
                        DataColumn(label: Text('Waktu scan')),
                        DataColumn(label: Text('Mode')),
                        DataColumn(label: Text('Kelas')),
                        DataColumn(label: Text('Akurasi rata-rata')),
                        DataColumn(label: Text('Jumlah pisang')),
                        DataColumn(label: Text('Hapus')),
                      ],
                      rows: [
                        for (var i = start; i < end; i++)
                          DataRow(cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(Text(fmtDate(DateTime.parse('${view[i]['created_at']}')))),
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
                            DataCell(Text('${(view[i]['akurasi'] as num).toStringAsFixed(1)}%')),
                            DataCell(Text('${view[i]['jumlah_objek']}')),
                            DataCell(IconButton(
                              tooltip: 'Hapus',
                              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600),
                              onPressed: () => _deleteOne(view[i]),
                            )),
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
        ],
      ],
    );
  }
}
