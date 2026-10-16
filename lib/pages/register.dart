import 'dart:async';
import 'package:flutter/material.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'login.dart';

/// Registrasi 3 langkah: 1) email, 2) kode OTP (membuktikan email benar-benar ada), 3) data akun.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int _step = 0;
  final _kEmail = GlobalKey<FormState>();
  final _kCode = GlobalKey<FormState>();
  final _kData = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _nama = TextEditingController();
  final _user = TextEditingController();
  final _telp = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  String? _gender;
  String _verifiedEmail = '';
  bool _loading = false;
  bool _done = false;
  int _cool = 0;
  Timer? _timer;

  @override
  void dispose() {
    // Email sudah terverifikasi tapi data belum disimpan: jangan biarkan sesi tersisa.
    if (_step == 2 && !_done) sb.auth.signOut();
    _timer?.cancel();
    for (final c in [_email, _code, _nama, _user, _telp, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cool = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cool--);
      if (_cool <= 0) t.cancel();
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (!resend && !_kEmail.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Api.sendRegisterOtp(_email.text);
      if (!mounted) return;
      setState(() => _step = 1);
      _startCooldown();
      toast(context, 'Kode OTP dikirim. Cek inbox atau folder spam.');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (!_kCode.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Api.verifyRegisterOtp(_email.text, _code.text);
      if (!mounted) return;
      setState(() {
        _verifiedEmail = _email.text.trim().toLowerCase();
        _step = 2;
      });
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_kData.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Api.completeRegistration(
        nama: _nama.text,
        username: _user.text,
        noTelp: _telp.text,
        gender: _gender!,
        password: _pass.text,
      );
      _done = true;
      if (!mounted) return;
      toast(context, 'Registrasi berhasil! Silakan masuk.');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _note(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: alpha(kAmber, .15), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(color: Colors.brown.shade700, fontSize: 12.5, height: 1.35)),
      );

  Widget _steps() {
    const labels = ['Email', 'Kode OTP', 'Data akun'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(height: 2, color: i <= _step ? kDeepAmber : kLine),
              ),
            ),
          Column(children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: i <= _step ? kDeepAmber : kLine,
              child: i < _step
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : Text('${i + 1}', style: TextStyle(color: i <= _step ? Colors.white : kBrown, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Text(labels[i], style: const TextStyle(fontSize: 11, color: kBrown)),
          ]),
        ],
      ]),
    );
  }

  Widget _stepEmail() {
    return Form(
      key: _kEmail,
      child: Column(children: [
        _note('Verifikasi email dulu supaya akunmu valid. Kami akan mengirim kode OTP ke email ini. Pastikan penulisannya benar.'),
        TextFormField(
          controller: _email,
          autocorrect: false,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
          validator: emailValidator,
        ),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: AppButton(label: 'Kirim Kode Verifikasi', icon: Icons.send_rounded, loading: _loading, onPressed: _sendCode)),
        const SizedBox(height: 14),
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Sudah punya akun? ', style: TextStyle(color: Colors.brown.shade400)),
          GestureDetector(
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())),
            child: const Text('Masuk', style: TextStyle(color: kDeepAmber, fontWeight: FontWeight.w800)),
          ),
        ]),
      ]),
    );
  }

  Widget _stepCode() {
    return Form(
      key: _kCode,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _note('Kode OTP dikirim ke ${_email.text.trim()}. Cek inbox atau folder spam. Salah email? Tekan "Ganti email".'),
        OtpField(controller: _code),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: AppButton(label: 'Verifikasi Kode', icon: Icons.verified_rounded, loading: _loading, onPressed: _verify)),
        const SizedBox(height: 6),
        Wrap(alignment: WrapAlignment.spaceBetween, children: [
          TextButton(
            onPressed: (_cool > 0 || _loading) ? null : () => _sendCode(resend: true),
            child: Text(_cool > 0 ? 'Kirim ulang kode (${_cool}s)' : 'Kirim ulang kode'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _code.clear();
              _step = 0;
            }),
            child: const Text('Ganti email'),
          ),
        ]),
      ]),
    );
  }

  Widget _stepData() {
    return Form(
      key: _kData,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: kGreen),
            const SizedBox(width: 10),
            Expanded(child: Text(_verifiedEmail, style: const TextStyle(fontWeight: FontWeight.w800, color: kBrown))),
            const Text('Terverifikasi', style: TextStyle(color: kGreen, fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ),
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
        PasswordPair(p1: _pass, p2: _pass2, label: 'Password'),
        const SizedBox(height: 22),
        SizedBox(width: double.infinity, child: AppButton(label: 'Daftar', icon: Icons.how_to_reg_rounded, loading: _loading, onPressed: _submit)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitles = [
      'Mulai dengan memverifikasi emailmu.',
      'Masukkan kode OTP dari email.',
      'Email terverifikasi. Lengkapi data akunmu.',
    ];
    return AuthScaffold(
      title: 'Buat akun',
      subtitle: subtitles[_step],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _steps(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, if (current != null) current],
          ),
          child: KeyedSubtree(
            key: ValueKey('reg$_step'),
            child: _step == 0 ? _stepEmail() : (_step == 1 ? _stepCode() : _stepData()),
          ),
        ),
      ]),
    );
  }
}
