import 'package:flutter/material.dart';
import '../charts.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _scans = [];
  bool _loading = true;
  int _shown = 15;

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

  Future<void> _clearAll() async {
    final ok = await confirmDialog(context, 'Hapus semua riwayat?', 'Seluruh riwayat scan kamu akan dihapus permanen.', okText: 'Hapus', danger: true);
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

    return PageWrap(
      title: 'Riwayat Scan',
      subtitle: 'Catatan semua hasil scan kamu.',
      trailing: _scans.isEmpty
          ? null
          : OutlinedButton.icon(
              onPressed: _clearAll,
              icon: Icon(Icons.delete_sweep_rounded, color: Colors.red.shade700),
              label: Text('Hapus Semua', style: TextStyle(color: Colors.red.shade700)),
            ),
      children: [
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (_scans.isEmpty)
          const AppCard(
            padding: EdgeInsets.symmetric(vertical: 50, horizontal: 20),
            child: Column(children: [
              Text('🍌', style: TextStyle(fontSize: 56)),
              SizedBox(height: 10),
              Text('Belum ada riwayat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kBrown)),
              SizedBox(height: 4),
              Text('Hasil scan akan muncul di sini secara otomatis.'),
            ]),
          )
        else ...[
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
          AppCard(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
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
                      for (var i = 0; i < _scans.length && i < _shown; i++)
                        DataRow(cells: [
                          DataCell(Text('${i + 1}')),
                          DataCell(Text(fmtDate(DateTime.parse('${_scans[i]['created_at']}')))),
                          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_scans[i]['mode'] == 'realtime' ? Icons.videocam_rounded : Icons.image_rounded, size: 16, color: kBrown),
                            const SizedBox(width: 6),
                            Text(_scans[i]['mode'] == 'realtime' ? 'Realtime' : 'Gambar'),
                          ])),
                          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 11, height: 11, decoration: BoxDecoration(color: infoKelas('${_scans[i]['kelas']}').warna, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(infoKelas('${_scans[i]['kelas']}').nama, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ])),
                          DataCell(Text('${(_scans[i]['akurasi'] as num).toStringAsFixed(1)}%')),
                          DataCell(Text('${_scans[i]['jumlah_objek']}')),
                          DataCell(IconButton(
                            tooltip: 'Hapus',
                            icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600),
                            onPressed: () => _deleteOne(_scans[i]),
                          )),
                        ]),
                    ],
                  ),
                ),
              ),
              if (_shown < _scans.length)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton(onPressed: () => setState(() => _shown += 15), child: Text('Tampilkan lebih banyak (${_scans.length - _shown} lagi)')),
                ),
            ]),
          ),
        ],
      ],
    );
  }
}
