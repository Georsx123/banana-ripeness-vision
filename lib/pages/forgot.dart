import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

/// Lupa password: kode OTP dikirim ke email akun yang username/emailnya diketik di halaman login.
class ForgotPage extends StatefulWidget {
  final String identifier;
  const ForgotPage({super.key, required this.identifier});
  @override
  State<ForgotPage> createState() => _ForgotPageState();
}

class _ForgotPageState extends State<ForgotPage> {
  bool _resolving = true;
  String? _email; // email akun (jika ditemukan dan valid)
  String? _problem; // pesan jika akun tidak bisa dipakai
  int _step = 0; // 0 kirim kode, 1 isi kode, 2 password baru
  final _kCode = GlobalKey<FormState>();
  final _kPass = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _loading = false;
  bool _done = false;
  int _cool = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void dispose() {
    // Kode benar tapi password belum disimpan: jangan biarkan sesi tersisa.
    if (_step == 2 && !_done) sb.auth.signOut();
    _timer?.cancel();
    _code.dispose();
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    try {
      final e = await Api.accountEmail(widget.identifier);
      if (!mounted) return;
      if (e == null) {
        _problem = 'Akun "${widget.identifier}" tidak ditemukan. Periksa penulisan username atau email di halaman login.';
      } else if (e.endsWith('@${AppConfig.emailDomain}')) {
        _problem = 'Akun ini belum punya email asli, jadi kode OTP tidak bisa dikirim. Hubungi admin lewat WhatsApp ${AppConfig.contactWa} untuk reset password.';
      } else {
        _email = e;
      }
    } catch (err) {
      _problem = Api.friendly(err);
    }
    if (mounted) setState(() => _resolving = false);
  }

  String _mask(String e) {
    final i = e.indexOf('@');
    if (i <= 2) return e;
    return '${e.substring(0, 2)}***${e.substring(i)}';
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

  Future<void> _sendCode() async {
    final email = _email;
    if (email == null) return;
    setState(() => _loading = true);
    try {
      await Api.sendResetOtp(email);
      if (!mounted) return;
      setState(() => _step = 1);
      _startCooldown();
      toast(context, 'Kode OTP dikirim ke ${_mask(email)}. Cek inbox atau folder spam.');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _email;
    if (email == null || !_kCode.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Api.verifyResetOtp(email, _code.text);
      if (mounted) setState(() => _step = 2);
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePassword() async {
    if (!_kPass.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Api.finishReset(_p1.text);
      _done = true;
      if (!mounted) return;
      toast(context, 'Password berhasil diubah. Silakan masuk dengan password baru.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _note(String text, {bool error = false}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: error ? Colors.red.shade50 : alpha(kAmber, .15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: TextStyle(color: error ? Colors.red.shade800 : Colors.brown.shade700, fontSize: 12.5, height: 1.35)),
      );

  Widget _body() {
    if (_resolving) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator()));
    }
    if (_problem != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _note(_problem!, error: true),
        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Kembali ke halaman masuk'))),
      ]);
    }
    if (_step == 0) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _note('Kode OTP akan dikirim ke email akun ini: ${_mask(_email!)}'),
        SizedBox(width: double.infinity, child: AppButton(label: 'Kirim Kode OTP', icon: Icons.send_rounded, loading: _loading, onPressed: _sendCode)),
      ]);
    }
    if (_step == 1) {
      return Form(
        key: _kCode,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _note('Kode OTP dikirim ke ${_mask(_email!)}. Cek inbox atau folder spam.'),
          OtpField(controller: _code),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: AppButton(label: 'Verifikasi Kode', icon: Icons.verified_rounded, loading: _loading, onPressed: _verifyCode)),
          const SizedBox(height: 6),
          TextButton(
            onPressed: (_cool > 0 || _loading) ? null : _sendCode,
            child: Text(_cool > 0 ? 'Kirim ulang kode (${_cool}s)' : 'Kirim ulang kode'),
          ),
        ]),
      );
    }
    return Form(
      key: _kPass,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _note('Kode benar. Buat password baru. Password lama tidak bisa ditampilkan karena disimpan terenkripsi.'),
        PasswordPair(p1: _p1, p2: _p2),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: AppButton(label: 'Simpan Password Baru', icon: Icons.lock_reset_rounded, loading: _loading, onPressed: _savePassword)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Lupa password',
      subtitle: 'Buat password baru lewat kode OTP di email.',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topLeft,
          children: [...previous, if (current != null) current],
        ),
        child: KeyedSubtree(key: ValueKey('forgot$_step$_resolving${_problem != null}'), child: _body()),
      ),
    );
  }
}
