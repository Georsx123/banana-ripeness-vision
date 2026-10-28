import 'package:flutter/material.dart';
import '../download.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import '../xlsx.dart';
import 'admin_flow.dart';
import 'package:flutter/foundation.dart';

/// Riwayat aktivitas admin di Admin Panel (dengan catatan waktu), bisa dicari, difilter, diekspor,
/// dan dibersihkan (pembersihan butuh izin dari admin lain).
class AdminLogPage extends StatefulWidget {
  const AdminLogPage({super.key});
  @override
  State<AdminLogPage> createState() => _AdminLogPageState();
}

class _AdminLogPageState extends State<AdminLogPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  int _perPage = 10;
  int _page = 0;
  String _q = '';
  String _fAksi = '';
  String _fAdmin = '';
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _rows = await Api.adminLogs();
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _view {
    final q = _q.trim().toLowerCase();
    return _rows.where((r) {
      final t = DateTime.tryParse('${r['created_at']}');
      if (_fAksi.isNotEmpty && '${r['aksi']}' != _fAksi) return false;
      if (_fAdmin.isNotEmpty && '${r['admin_nama']}' != _fAdmin) return false;
      if (t != null && !inDateRange(t, _range)) return false;
      if (q.isNotEmpty) {
        final hay = '${r['admin_nama']} ${r['aksi']} ${r['detail']}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _resetFilters() => setState(() {
        _q = '';
        _fAksi = '';
        _fAdmin = '';
        _range = null;
        _page = 0;
      });

  Future<void> _export() async {
    final view = _view;
    if (view.isEmpty) {
      toast(context, 'Tidak ada catatan untuk diekspor.', error: true);
      return;
    }
    final now = DateTime.now();
    final name = 'aktivitas_admin_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.xlsx';
    try {
      final bytes = buildXlsx(
        sheetName: 'Aktivitas Admin',
        headers: const ['No', 'Waktu', 'Admin', 'Aksi', 'Detail'],
        widths: const [6, 20, 22, 36, 70],
        centerCols: const [0],
        rows: [
          for (var i = 0; i < view.length; i++)
            <Object?>[
              i + 1,
              DateTime.tryParse('${view[i]['created_at']}'),
              '${view[i]['admin_nama']}',
              '${view[i]['aksi']}',
              '${view[i]['detail']}',
            ],
        ],
      );
      await saveBytesFile(name, bytes, xlsxMime);
      if (mounted && kIsWeb) toast(context, 'File $name diunduh');
    } catch (e) {
      if (mounted) toast(context, 'Gagal mengekspor: ${Api.friendly(e)}', error: true);
    }
  }

  Future<void> _clear() async {
    final izin = await requireApproval(
      context,
      jenis: 'clear_log',
      label: 'Riwayat aktivitas admin',
      judul: 'Bersihkan riwayat aktivitas',
      detail: 'Bersihkan seluruh riwayat aktivitas admin',
    );
    if (izin == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      'Bersihkan riwayat aktivitas?',
      'Seluruh catatan aktivitas admin akan dihapus permanen. Ekspor ke Excel dulu kalau ingin menyimpan salinannya. Izin hanya berlaku satu kali.',
      okText: 'Bersihkan',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.clearAdminLogs(izin: izin);
      await _load();
      if (mounted) {
        setState(() => _page = 0);
        toast(context, 'Riwayat aktivitas dibersihkan');
      }
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final pages = view.isEmpty ? 1 : (view.length + _perPage - 1) ~/ _perPage;
    final page = _page.clamp(0, pages - 1).toInt();
    final start = page * _perPage;
    final end = start + _perPage > view.length ? view.length : start + _perPage;
    final aksiList = (_rows.map((r) => '${r['aksi']}').toSet().toList())..sort();
    final adminList = (_rows.map((r) => '${r['admin_nama']}').toSet().toList())..sort();
    return PageWrap(
      title: 'Aktivitas Admin',
      subtitle: 'Catatan aktivitas admin di Admin Panel.',
      children: [
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (_rows.isEmpty)
          const AppCard(
            padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Center(child: Text('Belum ada aktivitas tercatat.')),
          )
        else ...[
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.download_rounded), label: const Text('Ekspor Excel')),
            OutlinedButton.icon(
              onPressed: _clear,
              icon: Icon(Icons.delete_sweep_rounded, color: Colors.red.shade700),
              label: Text('Bersihkan Riwayat (butuh izin admin lain)', style: TextStyle(color: Colors.red.shade700)),
            ),
          ]),
          const SizedBox(height: 14),
          FilterBar(
            hint: 'Cari admin, aksi, atau detail',
            onSearch: (v) => setState(() {
              _q = v;
              _page = 0;
            }),
            filters: [
              FilterDrop(
                label: 'Aksi',
                value: _fAksi,
                options: [const FOpt('', 'Semua aksi'), for (final a in aksiList) FOpt(a, a)],
                onChanged: (v) => setState(() {
                  _fAksi = v;
                  _page = 0;
                }),
              ),
              FilterDrop(
                label: 'Admin',
                value: _fAdmin,
                options: [const FOpt('', 'Semua admin'), for (final a in adminList) FOpt(a, a)],
                onChanged: (v) => setState(() {
                  _fAdmin = v;
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
                const Padding(padding: EdgeInsets.all(24), child: Text('Tidak ada catatan yang sesuai pencarian atau filter.'))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width > 1000 ? 900 : 760),
                    child: DataTable(
                      columnSpacing: 22,
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: double.infinity,
                      columns: const [
                        DataColumn(label: Text('No')),
                        DataColumn(label: Text('Waktu')),
                        DataColumn(label: Text('Admin')),
                        DataColumn(label: Text('Aksi')),
                        DataColumn(label: Text('Detail')),
                      ],
                      rows: [
                        for (var i = start; i < end; i++)
                          DataRow(cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(Text(fmtDate(DateTime.parse('${view[i]['created_at']}')))),
                            DataCell(Text('${view[i]['admin_nama']}')),
                            DataCell(Text('${view[i]['aksi']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: SizedBox(width: 340, child: Text('${view[i]['detail']}')),
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
