import 'package:flutter/material.dart';
import '../services.dart';
import '../widgets.dart';

class ForgotPage extends StatefulWidget {
  const ForgotPage({super.key});
  @override
  State<ForgotPage> createState() => _ForgotPageState();
}

class _ForgotPageState extends State<ForgotPage> {
  final _key = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _telp = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
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
      final ok = await Api.resetPasswordByPhone(_user.text, _telp.text, _pass.text);
      if (!mounted) return;
      if (ok) {
        toast(context, 'Password berhasil diubah. Silakan masuk.');
        Navigator.pop(context);
      } else {
        toast(context, 'Username dan no. telepon tidak cocok.', error: true);
      }
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Lupa password',
      subtitle: 'Masukkan username dan no. telepon yang terdaftar, lalu buat password baru.',
      child: Form(
        key: _key,
        child: Column(children: [
          TextFormField(
            controller: _user,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => requiredValidator(v, 'Username'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _telp,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'No. telepon terdaftar', prefixIcon: Icon(Icons.phone_outlined)),
            validator: (v) => requiredValidator(v, 'No. telepon'),
          ),
          const SizedBox(height: 14),
          PassField(
            controller: _pass,
            label: 'Password baru',
            validator: (v) => (v ?? '').length < 6 ? 'Minimal 6 karakter' : null,
          ),
          const SizedBox(height: 14),
          PassField(
            controller: _pass2,
            label: 'Konfirmasi password baru',
            action: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            validator: (v) => v != _pass.text ? 'Konfirmasi tidak sama' : null,
          ),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, child: AppButton(label: 'Ubah Password', loading: _loading, onPressed: _submit)),
        ]),
      ),
    );
  }
}
