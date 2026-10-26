import 'package:flutter/material.dart';
import '../download.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import '../xlsx.dart';
import 'admin_flow.dart';
import 'package:flutter/foundation.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<Profile> _users = [];
  bool _loading = true;
  String _q = '';
  String _fGender = '';
  String _fPlan = '';
  DateTimeRange? _range;
  int _perPageU = 10; // tabel user: bisa dipilih
  int _pageU = 0;
  int _pageA = 0; // tabel admin: tetap 10 per halaman
  static const int _perPageA = 10;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _users = await Api.allUsers();
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _resetFilters() => setState(() {
        _q = '';
        _fGender = '';
        _fPlan = '';
        _range = null;
        _pageU = 0;
        _pageA = 0;
      });

  bool _match(Profile u) {
    final q = _q.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = '${u.nama} ${u.username} ${u.email} ${u.noTelp}'.toLowerCase();
      if (!hay.contains(q)) return false;
    }
    if (_fGender.isNotEmpty && u.gender != _fGender) return false;
    if (u.createdAt != null && !inDateRange(u.createdAt!, _range)) return false;
    return true;
  }

  // ---- Aksi pada tabel: semuanya butuh izin admin lain ----
  Future<void> _edit(Profile u) async {
    final izin = await requireApproval(
      context,
      jenis: 'edit_user',
      targetId: u.id,
      label: '@${u.username}',
      judul: 'Ubah data pengguna',
      detail: 'Ubah data pengguna @${u.username} (${u.nama})',
    );
    if (izin == null || !mounted) return;
    final ok = await showDialog<bool>(context: context, builder: (_) => _UserDialog(user: u, izin: izin));
    if (ok == true) {
      await _load();
      if (mounted) toast(context, 'Data pengguna diperbarui');
    }
  }

  Future<void> _reset(Profile u) async {
    final izin = await requireApproval(
      context,
      jenis: 'reset_password',
      targetId: u.id,
      label: '@${u.username}',
      judul: 'Reset password pengguna',
      detail: 'Reset password pengguna @${u.username} (${u.nama})',
    );
    if (izin == null || !mounted) return;
    final pass = await showDialog<String>(context: context, builder: (_) => _ResetPasswordDialog(user: u));
    if (pass == null) return;
    try {
      await Api.adminResetPassword(u.id, pass, izin: izin);
      if (mounted) toast(context, 'Password berhasil direset');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
  }

  Future<void> _delete(Profile u) async {
    final izin = await requireApproval(
      context,
      jenis: 'delete_user',
      targetId: u.id,
      label: '@${u.username}',
      judul: 'Hapus pengguna',
      detail: 'Hapus pengguna @${u.username} (${u.nama}) beserta seluruh riwayat scan-nya',
    );
    if (izin == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      'Hapus pengguna?',
      'Akun @${u.username} beserta seluruh riwayat scan-nya akan dihapus permanen. Izin hanya berlaku satu kali.',
      okText: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.adminDeleteUser(u.id, izin: izin);
      await _load();
      if (mounted) toast(context, 'Pengguna dihapus');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
  }

  /// Ekspor tabel Info User (sesuai pencarian dan filter yang aktif, semua halaman) ke Excel.
  Future<void> _exportUsers(List<Profile> rows) async {
    if (rows.isEmpty) {
      toast(context, 'Tidak ada data user untuk diekspor.', error: true);
      return;
    }
    final ok = await confirmDialog(
      context,
      'Ekspor data user?',
      'File berisi data pribadi (nama, username, email, no. telepon) dari ${rows.length} user. Simpan dan bagikan dengan hati-hati.',
      okText: 'Ekspor',
    );
    if (!ok) return;
    final now = DateTime.now();
    final name = 'data_user_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.xlsx';
    try {
      final bytes = buildXlsx(
        sheetName: 'Data User',
        headers: const ['No', 'Nama', 'Username', 'Email', 'No. telepon', 'Jenis kelamin', 'Tipe user', 'Terdaftar'],
        widths: const [6, 28, 20, 32, 18, 16, 14, 20],
        centerCols: const [0, 5, 6],
        rows: [
          for (var i = 0; i < rows.length; i++)
            <Object?>[
              i + 1,
              rows[i].nama,
              rows[i].username,
              rows[i].hasRealEmail ? rows[i].email : '-',
              rows[i].noTelp,
              rows[i].gender.isEmpty ? '-' : rows[i].gender,
              planInfo(rows[i].plan).nama,
              rows[i].createdAt,
            ],
        ],
      );
      await saveBytesFile(name, bytes, xlsxMime);
      if (mounted && kIsWeb) toast(context, 'File $name diunduh');
    } catch (e) {
      if (mounted) toast(context, 'Gagal mengekspor: ${Api.friendly(e)}', error: true);
    }
  }

  Widget _table({
    required String title,
    required IconData icon,
    required List<Profile> rows,
    required int page,
    required int perPage,
    required ValueChanged<int> onPage,
    List<int>? options,
    ValueChanged<int>? onPerPage,
    Widget? action,
  }) {
    final pages = rows.isEmpty ? 1 : (rows.length + perPage - 1) ~/ perPage;
    final p = page.clamp(0, pages - 1).toInt();
    final start = p * perPage;
    final end = start + perPage > rows.length ? rows.length : start + perPage;
    final myId = AppState.me?.id;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: SectionTitle('$title (${rows.length})', icon)),
        if (action != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: action),
      ]),
      AppCard(
        padding: const EdgeInsets.all(8),
        child: Column(children: [
          if (rows.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Text('Tidak ada data.'))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width > 1000 ? 960 : 820),
                child: DataTable(
                  columnSpacing: 22,
                  columns: const [
                    DataColumn(label: Text('No')),
                    DataColumn(label: Text('Nama')),
                    DataColumn(label: Text('Username')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('No. telepon')),
                    DataColumn(label: Text('JK')),
                    DataColumn(label: Text('Tipe')),
                    DataColumn(label: Text('Terdaftar')),
                    DataColumn(label: Text('Aksi')),
                  ],
                  rows: [
                    for (var i = start; i < end; i++)
                      DataRow(cells: [
                        DataCell(Text('${i + 1}')),
                        DataCell(Text(rows[i].nama, style: const TextStyle(fontWeight: FontWeight.w700))),
                        DataCell(Text('@${rows[i].username}')),
                        DataCell(Text(rows[i].hasRealEmail ? rows[i].email : '-')),
                        DataCell(Text(rows[i].noTelp)),
                        DataCell(Text(rows[i].gender.isEmpty ? '-' : (rows[i].gender == 'Laki-laki' ? 'L' : 'P'))),
                        DataCell(PlanBadge(plan: rows[i].plan, admin: rows[i].isAdmin)),
                        DataCell(Text(rows[i].createdAt == null ? '-' : fmtDate(rows[i].createdAt!))),
                        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(tooltip: 'Edit (butuh izin admin lain)', icon: const Icon(Icons.edit_rounded, size: 20), onPressed: () => _edit(rows[i])),
                          IconButton(tooltip: 'Reset password (butuh izin admin lain)', icon: const Icon(Icons.key_rounded, size: 20), onPressed: () => _reset(rows[i])),
                          IconButton(
                            tooltip: rows[i].id == myId ? 'Tidak bisa hapus akun sendiri' : 'Hapus (butuh izin admin lain)',
                            icon: Icon(Icons.delete_outline_rounded, size: 20, color: rows[i].id == myId ? Colors.grey : Colors.red.shade600),
                            onPressed: rows[i].id == myId ? null : () => _delete(rows[i]),
                          ),
                        ])),
                      ]),
                  ],
                ),
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: PagerBar(
              total: rows.length,
              page: p,
              perPage: perPage,
              perPageOptions: options,
              onPage: onPage,
              onPerPage: onPerPage,
            ),
          ),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final list = _users.where(_match).toList();
    final users = list.where((u) => !u.isAdmin && (_fPlan.isEmpty || u.plan == _fPlan)).toList();
    final admins = list.where((u) => u.isAdmin).toList();
    final totalAdmin = _users.where((u) => u.isAdmin).length;
    return PageWrap(
      title: 'Kelola Pengguna',
      subtitle: '${_users.length - totalAdmin} user dan $totalAdmin admin terdaftar.',
      children: [
        if (!_loading && totalAdmin < 2)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(14)),
            child: Text(
              'Perhatian: edit, reset password, dan hapus butuh persetujuan 1 admin lain, tetapi saat ini hanya ada $totalAdmin akun admin. '
              'Tambahkan minimal 1 admin lagi (lewat SQL 02_jadikan_admin.sql) supaya aksi-aksi itu bisa disetujui.',
              style: TextStyle(color: Colors.red.shade800, height: 1.4, fontSize: 13),
            ),
          ),
        FilterBar(
          hint: 'Cari nama, username, email, atau no. telepon',
          onSearch: (v) => setState(() {
            _q = v;
            _pageU = 0;
            _pageA = 0;
          }),
          filters: [
            FilterDrop(
              label: 'Tipe (khusus user)',
              value: _fPlan,
              options: [const FOpt('', 'Semua tipe'), for (final p in planList) FOpt(p.key, p.nama)],
              onChanged: (v) => setState(() {
                _fPlan = v;
                _pageU = 0;
              }),
            ),
            FilterDrop(
              label: 'Jenis kelamin',
              value: _fGender,
              options: const [FOpt('', 'Semua'), FOpt('Laki-laki', 'Laki-laki'), FOpt('Perempuan', 'Perempuan')],
              onChanged: (v) => setState(() {
                _fGender = v;
                _pageU = 0;
                _pageA = 0;
              }),
            ),
          ],
          range: _range,
          onRange: (r) => setState(() {
            _range = r;
            _pageU = 0;
            _pageA = 0;
          }),
          onReset: _resetFilters,
        ),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else ...[
          _table(
            title: 'Info User',
            icon: Icons.people_alt_rounded,
            rows: users,
            page: _pageU,
            perPage: _perPageU,
            options: const [10, 25, 50, 100],
            onPage: (p) => setState(() => _pageU = p),
            onPerPage: (v) => setState(() {
              _perPageU = v;
              _pageU = 0;
            }),
            action: OutlinedButton.icon(
              onPressed: () => _exportUsers(users),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Ekspor Excel'),
            ),
          ),
          _table(
            title: 'Info Admin',
            icon: Icons.admin_panel_settings_rounded,
            rows: admins,
            page: _pageA,
            perPage: _perPageA,
            onPage: (p) => setState(() => _pageA = p),
          ),
        ],
      ],
    );
  }
}

/// Dialog edit pengguna (dibuka setelah izin dari admin lain disetujui).
class _UserDialog extends StatefulWidget {
  final Profile user;
  final int izin;
  const _UserDialog({required this.user, required this.izin});
  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _nama = TextEditingController(text: widget.user.nama);
  late final TextEditingController _telp = TextEditingController(text: widget.user.noTelp);
  String? _gender;
  late String _role;
  late String _plan;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _gender = (u.gender == 'Laki-laki' || u.gender == 'Perempuan') ? u.gender : null;
    _role = u.role;
    _plan = u.plan == 'admin' ? 'reguler' : u.plan;
  }

  @override
  void dispose() {
    _nama.dispose();
    _telp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Api.adminEditUser(
        widget.user.id,
        izin: widget.izin,
        nama: _nama.text,
        noTelp: _telp.text,
        gender: _gender ?? '',
        role: _role,
        plan: _role == 'admin' ? 'admin' : _plan,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = widget.user.id == AppState.me?.id;
    return AlertDialog(
      title: const Text('Edit pengguna'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 6),
              TextFormField(controller: _nama, decoration: const InputDecoration(labelText: 'Nama lengkap'), validator: (v) => requiredValidator(v, 'Nama')),
              const SizedBox(height: 12),
              TextFormField(initialValue: widget.user.username, enabled: false, decoration: const InputDecoration(labelText: 'Username')),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: widget.user.hasRealEmail ? widget.user.email : '-',
                enabled: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telp,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'No. telepon'),
                validator: (v) => RegExp(r'^\+?[0-9]{9,15}$').hasMatch((v ?? '').replaceAll(RegExp(r'[\s-]'), '')) ? null : 'No. telepon tidak valid',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Jenis kelamin'),
                items: const [
                  DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                  DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: InputDecoration(labelText: 'Role', helperText: isSelf ? 'Role akun sendiri tidak bisa diubah' : null),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: isSelf
                    ? null
                    : (v) => setState(() {
                          _role = v ?? 'user';
                          if (_role != 'admin' && _plan == 'admin') _plan = 'reguler';
                        }),
              ),
              const SizedBox(height: 12),
              if (_role == 'admin')
                TextFormField(
                  key: const ValueKey('planAdmin'),
                  initialValue: 'Admin (tanpa batas scan)',
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'Tipe user (paket scan)'),
                )
              else
                DropdownButtonFormField<String>(
                  key: const ValueKey('planUser'),
                  initialValue: _plan,
                  decoration: const InputDecoration(labelText: 'Tipe user (paket scan)'),
                  items: [
                    for (final p in planList) DropdownMenuItem(value: p.key, child: Text('${p.nama} \u2022 ${p.limit} scan/hari')),
                  ],
                  onChanged: (v) => setState(() => _plan = v ?? 'reguler'),
                ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

/// Dialog reset password oleh admin: password baru + konfirmasi, dengan tombol mata.
class _ResetPasswordDialog extends StatefulWidget {
  final Profile user;
  const _ResetPasswordDialog({required this.user});
  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _key = GlobalKey<FormState>();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reset password @${widget.user.username}'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 6),
              PasswordPair(p1: _p1, p2: _p2),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: () {
            if (_key.currentState!.validate()) Navigator.pop(context, _p1.text);
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
