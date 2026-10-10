import 'package:flutter/material.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'login.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _key = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _user = TextEditingController();
  final _telp = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  String? _gender;
  bool _loading = false;

  @override
  void dispose() {
    _nama.dispose();
    _user.dispose();
    _telp.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Api.register(
        nama: _nama.text,
        username: _user.text,
        noTelp: _telp.text,
        gender: _gender!,
        password: _pass.text,
      );
      if (!mounted) return;
      toast(context, 'Registrasi berhasil! Silakan masuk.');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Buat akun',
      subtitle: 'Isi data berikut untuk mendaftar.',
      child: Form(
        key: _key,
        child: Column(children: [
          TextFormField(
            controller: _nama,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama lengkap', prefixIcon: Icon(Icons.badge_outlined)),
            validator: (v) => requiredValidator(v, 'Nama'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _user,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Username',
              helperText: 'Huruf kecil, angka, titik, underscore (4-20 karakter)',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) {
              final s = (v ?? '').trim().toLowerCase();
              if (!RegExp(r'^[a-z0-9_.]{4,20}$').hasMatch(s)) return 'Username tidak valid';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _telp,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'No. telepon', prefixIcon: Icon(Icons.phone_outlined)),
            validator: (v) {
              final s = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
              if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(s)) return 'No. telepon tidak valid';
              return null;
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
            validator: (v) => v == null ? 'Pilih jenis kelamin' : null,
          ),
          const SizedBox(height: 14),
          PassField(
            controller: _pass,
            label: 'Password',
            validator: (v) => (v ?? '').length < 6 ? 'Minimal 6 karakter' : null,
          ),
          const SizedBox(height: 14),
          PassField(
            controller: _pass2,
            label: 'Konfirmasi password',
            action: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            validator: (v) => v != _pass.text ? 'Konfirmasi tidak sama' : null,
          ),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, child: AppButton(label: 'Daftar', loading: _loading, onPressed: _submit)),
          const SizedBox(height: 14),
          Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Sudah punya akun? ', style: TextStyle(color: Colors.brown.shade400)),
            GestureDetector(
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())),
              child: const Text('Masuk', style: TextStyle(color: kDeepAmber, fontWeight: FontWeight.w800)),
            ),
          ]),
        ]),
      ),
    );
  }
}
