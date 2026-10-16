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
  bool _resending = false;
  String? _pendingEmail; // email yang belum diverifikasi

  @override
  void dispose() {
    _u.dispose();
    _p.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _pendingEmail = null;
    });
    try {
      await Api.login(_u.text, _p.text);
      AppState.showOffer = true;
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
    } on EmailNotVerified catch (e) {
      if (mounted) setState(() => _pendingEmail = e.email);
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final email = _pendingEmail;
    if (email == null) return;
    setState(() => _resending = true);
    try {
      await Api.resendSignupEmail(email);
      if (mounted) toast(context, 'Email verifikasi dikirim ulang. Cek inbox atau folder spam.');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _resending = false);
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
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Username atau email', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => requiredValidator(v, 'Username atau email'),
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
              onPressed: () {
                final id = _u.text.trim();
                if (id.isEmpty) {
                  toast(context, 'Isi username atau email di kolom atas dulu, lalu tekan Lupa password.', error: true);
                  return;
                }
                Navigator.push(context, MaterialPageRoute(builder: (_) => ForgotPage(identifier: id)));
              },
              child: const Text('Lupa password?'),
            ),
          ),
          if (_pendingEmail != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: alpha(kAmber, .18), borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Email belum diverifikasi', style: TextStyle(fontWeight: FontWeight.w800, color: kBrown)),
                const SizedBox(height: 4),
                Text('Klik link verifikasi yang dikirim ke $_pendingEmail (cek juga folder spam), lalu coba masuk lagi.',
                    style: TextStyle(color: Colors.brown.shade600, height: 1.35)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _resending ? null : _resend,
                  icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                  label: Text(_resending ? 'Mengirim...' : 'Kirim ulang email verifikasi'),
                ),
              ]),
            ),
          ],
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
