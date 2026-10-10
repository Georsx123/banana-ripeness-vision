import 'package:flutter/material.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<Profile> _users = [];
  bool _loading = true;
  String _q = '';

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

  Future<void> _form([Profile? u]) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _UserDialog(user: u));
    if (ok == true) {
      await _load();
      if (mounted) toast(context, u == null ? 'Pengguna ditambahkan' : 'Data pengguna diperbarui');
    }
  }

  Future<void> _reset(Profile u) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset password @${u.username}'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Password baru (min. 6 karakter)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    final pass = c.text;
    if (ok != true) return;
    if (pass.length < 6) {
      if (mounted) toast(context, 'Password minimal 6 karakter', error: true);
      return;
    }
    try {
      await Api.adminResetPassword(u.id, pass);
      if (mounted) toast(context, 'Password berhasil direset');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
  }

  Future<void> _delete(Profile u) async {
    final ok = await confirmDialog(context, 'Hapus pengguna?', 'Akun @${u.username} beserta seluruh riwayat scan-nya akan dihapus permanen.', okText: 'Hapus', danger: true);
    if (!ok) return;
    try {
      await Api.adminDeleteUser(u.id);
      await _load();
      if (mounted) toast(context, 'Pengguna dihapus');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = _users.where((u) => u.nama.toLowerCase().contains(q) || u.username.toLowerCase().contains(q) || u.noTelp.contains(q)).toList();
    final myId = AppState.me?.id;
    return PageWrap(
      title: 'Kelola Pengguna',
      subtitle: '${_users.length} pengguna terdaftar.',
      trailing: ElevatedButton.icon(onPressed: () => _form(), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Tambah')),
      children: [
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(hintText: 'Cari nama, username, atau no. telepon', prefixIcon: Icon(Icons.search_rounded)),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else
          AppCard(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width > 1000 ? 900 : 720),
                child: DataTable(
                  columnSpacing: 22,
                  columns: const [
                    DataColumn(label: Text('Nama')),
                    DataColumn(label: Text('Username')),
                    DataColumn(label: Text('No. telepon')),
                    DataColumn(label: Text('JK')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Terdaftar')),
                    DataColumn(label: Text('Aksi')),
                  ],
                  rows: [
                    for (final u in list)
                      DataRow(cells: [
                        DataCell(Text(u.nama, style: const TextStyle(fontWeight: FontWeight.w700))),
                        DataCell(Text('@${u.username}')),
                        DataCell(Text(u.noTelp)),
                        DataCell(Text(u.gender.isEmpty ? '-' : (u.gender == 'Laki-laki' ? 'L' : 'P'))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: alpha(u.isAdmin ? kGreen : kAmber, .2), borderRadius: BorderRadius.circular(20)),
                          child: Text(u.isAdmin ? 'Admin' : 'User', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        )),
                        DataCell(Text(u.createdAt == null ? '-' : fmtDate(u.createdAt!))),
                        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_rounded, size: 20), onPressed: () => _form(u)),
                          IconButton(tooltip: 'Reset password', icon: const Icon(Icons.key_rounded, size: 20), onPressed: () => _reset(u)),
                          IconButton(
                            tooltip: u.id == myId ? 'Tidak bisa hapus akun sendiri' : 'Hapus',
                            icon: Icon(Icons.delete_outline_rounded, size: 20, color: u.id == myId ? Colors.grey : Colors.red.shade600),
                            onPressed: u.id == myId ? null : () => _delete(u),
                          ),
                        ])),
                      ]),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UserDialog extends StatefulWidget {
  final Profile? user;
  const _UserDialog({this.user});
  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _nama = TextEditingController(text: widget.user?.nama ?? '');
  late final TextEditingController _user = TextEditingController(text: widget.user?.username ?? '');
  late final TextEditingController _telp = TextEditingController(text: widget.user?.noTelp ?? '');
  final _pass = TextEditingController();
  String? _gender;
  String _role = 'user';
  bool _loading = false;

  bool get _edit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    if (u != null) {
      _gender = (u.gender == 'Laki-laki' || u.gender == 'Perempuan') ? u.gender : null;
      _role = u.role;
    }
  }

  @override
  void dispose() {
    _nama.dispose();
    _user.dispose();
    _telp.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_edit) {
        await Api.adminUpdateUser(widget.user!.id, nama: _nama.text, noTelp: _telp.text, gender: _gender ?? '', role: _role);
      } else {
        await Api.adminCreateUser(
          nama: _nama.text,
          username: _user.text,
          noTelp: _telp.text,
          gender: _gender ?? '',
          password: _pass.text,
          role: _role,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = widget.user?.id == AppState.me?.id;
    return AlertDialog(
      title: Text(_edit ? 'Edit pengguna' : 'Tambah pengguna'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 6),
              TextFormField(controller: _nama, decoration: const InputDecoration(labelText: 'Nama lengkap'), validator: (v) => requiredValidator(v, 'Nama')),
              const SizedBox(height: 12),
              TextFormField(
                controller: _user,
                enabled: !_edit,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) => RegExp(r'^[a-z0-9_.]{4,20}$').hasMatch((v ?? '').trim().toLowerCase()) ? null : 'Username tidak valid (4-20, huruf kecil/angka/._)',
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
                onChanged: isSelf ? null : (v) => setState(() => _role = v ?? 'user'),
              ),
              if (!_edit) ...[
                const SizedBox(height: 12),
                PassField(
                  controller: _pass,
                  label: 'Password',
                  action: TextInputAction.done,
                  validator: (v) => (v ?? '').length < 6 ? 'Minimal 6 karakter' : null,
                ),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Simpan'),
        ),
      ],
    );
  }
}
