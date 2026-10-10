import 'package:flutter/material.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'forgot.dart';
import 'register.dart';
import 'shell.dart';
import 'splash.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _key = GlobalKey<FormState>();
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _u.dispose();
    _p.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Api.login(_u.text, _p.text);
      if (!mounted) return;
      final nama = AppState.me?.nama ?? '';
      Navigator.of(context).pushAndRemoveUntil(
        fadeRoute(BrandSplash(
          title: 'Halo, $nama!',
          subtitle: 'Senang bertemu lagi. Yuk cek pisangmu!',
          duration: SplashTiming.afterLogin,
          onDone: (ctx) => Navigator.of(ctx).pushReplacement(fadeRoute(const Shell())),
        )),
        (r) => false,
      );
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Selamat datang',
      subtitle: 'Masuk untuk mulai memindai pisang.',
      child: Form(
        key: _key,
        child: Column(children: [
          TextFormField(
            controller: _u,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => requiredValidator(v, 'Username'),
          ),
          const SizedBox(height: 14),
          PassField(
            controller: _p,
            label: 'Password',
            action: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            validator: (v) => requiredValidator(v, 'Password'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPage())),
              child: const Text('Lupa password?'),
            ),
          ),
          SizedBox(width: double.infinity, child: AppButton(label: 'Masuk', loading: _loading, onPressed: _submit)),
          const SizedBox(height: 14),
          Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Belum punya akun? ', style: TextStyle(color: Colors.brown.shade400)),
            GestureDetector(
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
              child: const Text('Daftar', style: TextStyle(color: kDeepAmber, fontWeight: FontWeight.w800)),
            ),
          ]),
        ]),
      ),
    );
  }
}
