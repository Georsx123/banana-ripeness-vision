import 'package:flutter/material.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class _Entry {
  final bool request; // true = permintaan izin otomatis, false = catatan manual
  final Map<String, dynamic> m;
  final DateTime time;
  final bool isNew;
  const _Entry(this.request, this.m, this.time, this.isNew);
}

/// Pesan admin: catatan manual + permintaan izin antar admin (otomatis).
class AdminPesanPage extends StatefulWidget {
  const AdminPesanPage({super.key});
  @override
  State<AdminPesanPage> createState() => _AdminPesanPageState();
}

class _AdminPesanPageState extends State<AdminPesanPage> {
  List<_Entry> _entries = [];
  bool _loading = true;
  int _perPage = 10;
  int _page = 0;
  String _q = '';
  String _fType = '';
  String _fStatus = '';
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final seen = await Api.pesanDilihat();
      final notes = await Api.adminPesan();
      final reqs = await Api.adminRequests();
      final me = sb.auth.currentUser?.id;
      final list = <_Entry>[];
      for (final n in notes) {
        final t = DateTime.parse('${n['created_at']}').toLocal();
        list.add(_Entry(false, n, t, n['dibuat_oleh'] != me && t.isAfter(seen)));
      }
      for (final r in reqs) {
        final t = DateTime.parse('${r['created_at']}').toLocal();
        final mine = r['dibuat_oleh'] == me;
        final dec = r['diputus_pada'] == null ? null : DateTime.parse('${r['diputus_pada']}').toLocal();
        final isNew = (!mine && t.isAfter(seen)) || (mine && dec != null && dec.isAfter(seen));
        list.add(_Entry(true, r, t, isNew));
      }
      list.sort((a, b) => b.time.compareTo(a.time));
      _entries = list;
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
    // Tandai sudah dilihat. Titik "baru" di kartu tetap tampil selama halaman ini terbuka.
    Api.tandaiPesanDibaca();
  }

  // ---------- bantuan tampilan ----------
  bool _expired(Map<String, dynamic> r) {
    if (r['status'] != 'disetujui' || r['diputus_pada'] == null) return false;
    final d = DateTime.parse('${r['diputus_pada']}').toLocal();
    return DateTime.now().isAfter(d.add(const Duration(hours: 1)));
  }

  (String, Color) _statusOf(Map<String, dynamic> r) {
    switch ('${r['status']}') {
      case 'menunggu':
        return ('Menunggu persetujuan', const Color(0xFFF9A825));
      case 'disetujui':
        return _expired(r) ? ('Kedaluwarsa', Colors.grey) : ('Disetujui', kGreen);
      case 'ditolak':
        return ('Ditolak', Colors.red.shade700);
      case 'dipakai':
        return ('Sudah dipakai', const Color(0xFF1E88E5));
      default:
        return ('Dibatalkan', Colors.grey);
    }
  }

  String _judul(String j) => switch (j) {
        'edit_user' => 'Izin ubah data pengguna',
        'reset_password' => 'Izin reset password pengguna',
        'delete_user' => 'Izin hapus pengguna',
        'clear_log' => 'Izin bersihkan riwayat aktivitas',
        _ => 'Permintaan izin',
      };

  IconData _icon(String j) => switch (j) {
        'edit_user' => Icons.edit_rounded,
        'reset_password' => Icons.key_rounded,
        'delete_user' => Icons.person_remove_rounded,
        'clear_log' => Icons.delete_sweep_rounded,
        _ => Icons.help_outline_rounded,
      };

  Widget _dot() => Container(
        width: 11,
        height: 11,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
      );

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 92, child: Text(k, style: TextStyle(color: Colors.brown.shade400, fontSize: 12.5))),
          Expanded(child: Text(v, style: const TextStyle(color: kBrown, fontSize: 13.5, height: 1.35))),
        ]),
      );

  // ---------- aksi ----------
  Future<void> _add() async {
    final text = await showDialog<String>(context: context, builder: (_) => const _PesanDialog());
    if (text == null) return;
    try {
      await Api.addPesan(text);
      await _load();
      if (mounted) toast(context, 'Pesan disimpan');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
  }

  Future<void> _deleteNote(Map<String, dynamic> item) async {
    final alasan = await showDialog<String>(context: context, builder: (_) => const _AlasanDialog());
    if (alasan == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      'Hapus pesan ini?',
      'Alasan: $alasan\n\nPesan akan dihapus permanen, dan alasannya dicatat di riwayat aktivitas admin.',
      okText: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.deletePesan(item['id'] as int, '${item['isi']}', alasan);
      await _load();
      if (mounted) toast(context, 'Pesan dihapus');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
  }

  Future<void> _decide(Map<String, dynamic> r, bool setuju) async {
    var catatan = '';
    if (setuju) {
      final ok = await confirmDialog(
        context,
        'Setujui permintaan ini?',
        '${r['detail']}\n\nPemohon: ${r['dibuat_nama']}\nAlasan: ${r['alasan']}\n\nPemohon dapat melakukan aksinya satu kali dalam 1 jam setelah disetujui.',
        okText: 'Setujui',
      );
      if (!ok) return;
    } else {
      final c = await showDialog<String>(context: context, builder: (_) => const _TolakDialog());
      if (c == null) return;
      catatan = c;
    }
    try {
      await Api.decideRequest(r['id'] as int, setuju, catatan);
      await _load();
      if (mounted) toast(context, setuju ? 'Permintaan disetujui' : 'Permintaan ditolak');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
  }

  Future<void> _cancel(Map<String, dynamic> r) async {
    final ok = await confirmDialog(context, 'Batalkan permintaan?', '${r['detail']}', okText: 'Batalkan', danger: true);
    if (!ok) return;
    try {
      await Api.cancelRequest(r['id'] as int);
      await _load();
      if (mounted) toast(context, 'Permintaan dibatalkan');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
  }

  // ---------- filter ----------
  List<_Entry> get _view {
    final q = _q.trim().toLowerCase();
    return _entries.where((e) {
      if (_fType == 'catatan' && e.request) return false;
      if (_fType == 'permintaan' && !e.request) return false;
      if (_fStatus.isNotEmpty && (!e.request || '${e.m['status']}' != _fStatus)) return false;
      if (!inDateRange(e.time, _range)) return false;
      if (q.isNotEmpty) {
        final hay = e.request
            ? '${_judul('${e.m['jenis']}')} ${e.m['detail']} ${e.m['alasan']} ${e.m['dibuat_nama']} ${e.m['diputus_nama']} ${e.m['target_label']} ${e.m['status']}'
            : '${e.m['isi']} ${e.m['dibuat_nama']}';
        if (!hay.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _resetFilters() => setState(() {
        _q = '';
        _fType = '';
        _fStatus = '';
        _range = null;
        _page = 0;
      });

  // ---------- kartu ----------
  Widget _noteCard(_Entry e) {
    final i = e.m;
    return AppCard(
      color: const Color(0xFFFFF8E1),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (e.isNew) _dot(),
          const Icon(Icons.sticky_note_2_rounded, color: kDeepAmber),
          const SizedBox(width: 8),
          Expanded(child: Text('Catatan \u2022 ${fmtDate(e.time)}', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.brown.shade500, fontSize: 12.5))),
          IconButton(tooltip: 'Hapus', icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600), onPressed: () => _deleteNote(i)),
        ]),
        const SizedBox(height: 6),
        SelectableText('${i['isi']}', style: const TextStyle(height: 1.45, color: kBrown, fontSize: 15)),
        const SizedBox(height: 10),
        Text('Dibuat oleh ${i['dibuat_nama'] ?? '-'}', style: TextStyle(color: Colors.brown.shade400, fontSize: 12)),
      ]),
    );
  }

  Widget _requestCard(_Entry e) {
    final r = e.m;
    final me = sb.auth.currentUser?.id;
    final mine = r['dibuat_oleh'] == me;
    final status = '${r['status']}';
    final (label, color) = _statusOf(r);
    final decTime = r['diputus_pada'] == null ? null : DateTime.parse('${r['diputus_pada']}').toLocal();
    final valid = status == 'disetujui' && !_expired(r);
    final jenis = '${r['jenis']}';
    return AppCard(
      color: alpha(color, .07),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (e.isNew) _dot(),
          Icon(_icon(jenis), color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(_judul(jenis), style: const TextStyle(fontWeight: FontWeight.w800, color: kBrown))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: alpha(color, .2), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 8),
        Text('${r['detail']}', style: const TextStyle(fontWeight: FontWeight.w700, color: kBrown, height: 1.35)),
        const SizedBox(height: 6),
        _line('Pemohon', '${r['dibuat_nama']}${mine ? ' (kamu)' : ''}'),
        _line('Alasan', '${r['alasan']}'),
        _line('Diajukan', fmtDate(e.time)),
        if (decTime != null && '${r['diputus_nama']}'.isNotEmpty)
          _line(status == 'ditolak' ? 'Ditolak oleh' : 'Diputus oleh', '${r['diputus_nama']} \u2022 ${fmtDate(decTime)}'),
        if ('${r['catatan_keputusan']}'.isNotEmpty) _line('Catatan', '${r['catatan_keputusan']}'),
        if (valid && mine && decTime != null) ...[
          const SizedBox(height: 8),
          Text(
            'Disetujui. Berlaku sampai ${two(decTime.add(const Duration(hours: 1)).hour)}:${two(decTime.add(const Duration(hours: 1)).minute)}. '
            'Ulangi aksinya di menu terkait; izin hanya berlaku satu kali.',
            style: const TextStyle(color: kGreen, fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.35),
          ),
        ],
        if (status == 'menunggu' || (valid && mine)) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (status == 'menunggu' && !mine) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: () => _decide(r, true),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Setujui'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: () => _decide(r, false),
                icon: Icon(Icons.close_rounded, size: 18, color: Colors.red.shade700),
                label: Text('Tolak', style: TextStyle(color: Colors.red.shade700)),
              ),
            ],
            if (status == 'menunggu' && mine)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Menunggu admin lain menyetujui.', style: TextStyle(color: Colors.brown.shade500, fontSize: 12.5)),
              ),
            if (mine && (status == 'menunggu' || valid))
              TextButton.icon(onPressed: () => _cancel(r), icon: const Icon(Icons.undo_rounded, size: 18), label: const Text('Batalkan')),
          ]),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final pages = view.isEmpty ? 1 : (view.length + _perPage - 1) ~/ _perPage;
    final page = _page.clamp(0, pages - 1).toInt();
    final start = page * _perPage;
    final end = start + _perPage > view.length ? view.length : start + _perPage;
    return PageWrap(
      title: 'Pesan',
      subtitle: 'Catatan admin dan permintaan izin antar admin (otomatis).',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(tooltip: 'Muat ulang', icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        const SizedBox(width: 4),
        ElevatedButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded), label: const Text('Add Pesan')),
      ]),
      children: [
        FilterBar(
          hint: 'Cari isi pesan, alasan, atau nama',
          onSearch: (v) => setState(() {
            _q = v;
            _page = 0;
          }),
          filters: [
            FilterDrop(
              label: 'Jenis',
              value: _fType,
              options: const [FOpt('', 'Semua'), FOpt('catatan', 'Catatan'), FOpt('permintaan', 'Permintaan izin')],
              onChanged: (v) => setState(() {
                _fType = v;
                _page = 0;
              }),
            ),
            FilterDrop(
              label: 'Status izin',
              value: _fStatus,
              options: const [
                FOpt('', 'Semua status'),
                FOpt('menunggu', 'Menunggu'),
                FOpt('disetujui', 'Disetujui'),
                FOpt('ditolak', 'Ditolak'),
                FOpt('dipakai', 'Sudah dipakai'),
                FOpt('dibatalkan', 'Dibatalkan'),
              ],
              onChanged: (v) => setState(() {
                _fStatus = v;
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
        const SizedBox(height: 14),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (view.isEmpty)
          const AppCard(
            padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Center(child: Text('Tidak ada pesan. Tekan "Add Pesan" untuk menulis catatan.')),
          )
        else ...[
          ResponsiveWrap(minWidth: 340, children: [
            for (var i = start; i < end; i++) view[i].request ? _requestCard(view[i]) : _noteCard(view[i]),
          ]),
          const SizedBox(height: 14),
          AppCard(
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
        ],
      ],
    );
  }
}

class _PesanDialog extends StatefulWidget {
  const _PesanDialog();
  @override
  State<_PesanDialog> createState() => _PesanDialogState();
}

class _PesanDialogState extends State<_PesanDialog> {
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
      title: const Text('Tambah pesan'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _key,
          child: TextFormField(
            controller: _c,
            maxLines: 6,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Isi pesan', alignLabelWithHint: true),
            validator: (v) => requiredValidator(v, 'Isi pesan'),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: () {
            if (_key.currentState!.validate()) Navigator.pop(context, _c.text.trim());
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

/// Catatan saat menolak permintaan (opsional).
class _TolakDialog extends StatefulWidget {
  const _TolakDialog();
  @override
  State<_TolakDialog> createState() => _TolakDialogState();
}

class _TolakDialogState extends State<_TolakDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tolak permintaan'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _c,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Catatan penolakan (opsional)', alignLabelWithHint: true),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44), backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.pop(context, _c.text.trim()),
          child: const Text('Tolak'),
        ),
      ],
    );
  }
}

/// Alasan menghapus catatan: sudah selesai / tidak jadi / lainnya (tulis sendiri).
class _AlasanDialog extends StatefulWidget {
  const _AlasanDialog();
  @override
  State<_AlasanDialog> createState() => _AlasanDialogState();
}

class _AlasanDialogState extends State<_AlasanDialog> {
  static const _opsi = ['Sudah selesai masalahnya', 'Tidak jadi', 'Lainnya'];
  String? _pilih;
  final _lain = TextEditingController();

  @override
  void dispose() {
    _lain.dispose();
    super.dispose();
  }

  bool get _valid => _pilih != null && (_pilih != 'Lainnya' || _lain.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kenapa pesan ini dihapus?'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final o in _opsi)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(_pilih == o ? Icons.radio_button_checked : Icons.radio_button_off, color: _pilih == o ? kDeepAmber : Colors.grey),
                title: Text(o, style: TextStyle(fontWeight: _pilih == o ? FontWeight.w800 : FontWeight.w500)),
                onTap: () => setState(() => _pilih = o),
              ),
            if (_pilih == 'Lainnya') ...[
              const SizedBox(height: 6),
              TextField(
                controller: _lain,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Tulis alasannya'),
              ),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: _valid ? () => Navigator.pop(context, _pilih == 'Lainnya' ? 'Lainnya: ${_lain.text.trim()}' : _pilih) : null,
          child: const Text('Lanjut'),
        ),
      ],
    );
  }
}
