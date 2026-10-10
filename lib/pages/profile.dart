import 'package:flutter/material.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _k1 = GlobalKey<FormState>();
  final _k2 = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _telp;
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  String? _gender;
  bool _saving = false, _savingPass = false;

  @override
  void initState() {
    super.initState();
    final me = AppState.me!;
    _nama = TextEditingController(text: me.nama);
    _telp = TextEditingController(text: me.noTelp);
    _gender = (me.gender == 'Laki-laki' || me.gender == 'Perempuan') ? me.gender : null;
  }

  @override
  void dispose() {
    _nama.dispose();
    _telp.dispose();
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_k1.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await Api.updateMyProfile(nama: _nama.text, noTelp: _telp.text, gender: _gender ?? '');
      if (mounted) toast(context, 'Profil berhasil diperbarui');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePass() async {
    if (!_k2.currentState!.validate()) return;
    setState(() => _savingPass = true);
    try {
      await Api.changeMyPassword(_p1.text);
      _p1.clear();
      _p2.clear();
      if (mounted) toast(context, 'Password berhasil diganti');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _savingPass = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = AppState.me!;
    return PageWrap(
      title: 'Profil',
      subtitle: 'Kelola data akun kamu.',
      children: [
        AppCard(
          child: Row(children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: alpha(kAmber, .25),
              child: Text(me.nama.isEmpty ? '?' : me.nama.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: kDeepAmber)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(me.nama, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kBrown)),
                Text('@${me.username}', style: TextStyle(color: Colors.brown.shade400)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: alpha(me.isAdmin ? kGreen : kAmber, .18),
                    side: BorderSide.none,
                    label: Text(me.isAdmin ? 'Admin' : 'Pengguna'),
                  ),
                  if (me.createdAt != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                      backgroundColor: Colors.grey.shade200,
                      label: Text('Bergabung ${fmtDate(me.createdAt!).substring(0, 10)}'),
                    ),
                ]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        ResponsiveWrap(minWidth: 440, children: [
          AppCard(
            child: Form(
              key: _k1,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Data pribadi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kBrown)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nama,
                  decoration: const InputDecoration(labelText: 'Nama lengkap', prefixIcon: Icon(Icons.badge_outlined)),
                  validator: (v) => requiredValidator(v, 'Nama'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: me.username,
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'Username (tidak bisa diubah)', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _telp,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'No. telepon', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) {
                    final s = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
                    return RegExp(r'^\+?[0-9]{9,15}$').hasMatch(s) ? null : 'No. telepon tidak valid';
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(labelText: 'Jenis kelamin', prefixIcon: Icon(Icons.wc_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                    DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                ),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: AppButton(label: 'Simpan Perubahan', icon: Icons.save_rounded, loading: _saving, onPressed: _save)),
              ]),
            ),
          ),
          AppCard(
            child: Form(
              key: _k2,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Ganti password', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kBrown)),
                const SizedBox(height: 16),
                PassField(
                  controller: _p1,
                  label: 'Password baru',
                  validator: (v) => (v ?? '').length < 6 ? 'Minimal 6 karakter' : null,
                ),
                const SizedBox(height: 14),
                PassField(
                  controller: _p2,
                  label: 'Konfirmasi password baru',
                  action: TextInputAction.done,
                  validator: (v) => v != _p1.text ? 'Konfirmasi tidak sama' : null,
                ),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: AppButton(label: 'Ganti Password', icon: Icons.lock_reset_rounded, loading: _savingPass, onPressed: _savePass)),
              ]),
            ),
          ),
        ]),
      ],
    );
  }
}
