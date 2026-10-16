import 'dart:async';
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
  final _code = TextEditingController();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  String? _gender;
  bool _saving = false;
  bool _otpSent = false;
  bool _otpLoading = false;
  bool _savingPass = false;
  int _cool = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Api.refreshQuota();
    Api.loadProfile().then((_) {
      if (mounted) setState(() {});
    }, onError: (_) {});
    final me = AppState.me!;
    _nama = TextEditingController(text: me.nama);
    _telp = TextEditingController(text: me.noTelp);
    _gender = (me.gender == 'Laki-laki' || me.gender == 'Perempuan') ? me.gender : null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nama.dispose();
    _telp.dispose();
    _code.dispose();
    _p1.dispose();
    _p2.dispose();
    super.dispose();
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

  Future<void> _sendOtp() async {
    setState(() => _otpLoading = true);
    try {
      await Api.sendProfileOtp();
      if (!mounted) return;
      setState(() => _otpSent = true);
      _startCooldown();
      toast(context, 'Kode OTP dikirim ke emailmu. Cek inbox atau folder spam.');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _otpLoading = false);
    }
  }

  Future<void> _savePass() async {
    if (!_k2.currentState!.validate()) return;
    setState(() => _savingPass = true);
    try {
      await Api.changePasswordWithOtp(_code.text, _p1.text);
      _code.clear();
      _p1.clear();
      _p2.clear();
      if (!mounted) return;
      setState(() => _otpSent = false);
      toast(context, 'Password berhasil diganti');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _savingPass = false);
    }
  }

  Widget _passwordCard(Profile me) {
    final title = const Text('Ganti password', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kBrown));
    if (!me.hasRealEmail) {
      return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          title,
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: alpha(kAmber, .18), borderRadius: BorderRadius.circular(14)),
            child: Text(
              'Akun ini belum punya email asli, jadi kode OTP tidak bisa dikirim. Untuk memakai fitur ini, daftar akun baru dengan email asli.',
              style: TextStyle(color: Colors.brown.shade700, height: 1.4),
            ),
          ),
        ]),
      );
    }
    if (!_otpSent) {
      return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          title,
          const SizedBox(height: 14),
          Text('Demi keamanan, kode OTP akan dikirim ke ${_mask(me.email)} sebelum password diganti.',
              style: TextStyle(color: Colors.brown.shade600, height: 1.4)),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: AppButton(label: 'Kirim Kode OTP', icon: Icons.send_rounded, loading: _otpLoading, onPressed: _sendOtp)),
        ]),
      );
    }
    return AppCard(
      child: Form(
        key: _k2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          title,
          const SizedBox(height: 14),
          Text('Kode OTP dikirim ke ${_mask(me.email)}.', style: TextStyle(color: Colors.brown.shade600)),
          const SizedBox(height: 12),
          OtpField(controller: _code),
          const SizedBox(height: 6),
          PasswordPair(p1: _p1, p2: _p2),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: AppButton(label: 'Ganti Password', icon: Icons.lock_reset_rounded, loading: _savingPass, onPressed: _savePass)),
          const SizedBox(height: 6),
          Wrap(alignment: WrapAlignment.spaceBetween, children: [
            TextButton(
              onPressed: (_cool > 0 || _otpLoading) ? null : _sendOtp,
              child: Text(_cool > 0 ? 'Kirim ulang kode (${_cool}s)' : 'Kirim ulang kode'),
            ),
            TextButton(onPressed: () => setState(() => _otpSent = false), child: const Text('Batal')),
          ]),
        ]),
      ),
    );
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
                  PlanBadge(plan: me.plan, admin: me.isAdmin),
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
        const QuotaBar(),
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
                  initialValue: me.hasRealEmail ? me.email : 'Belum ada email asli',
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'Email (tidak bisa diubah)', prefixIcon: Icon(Icons.email_outlined)),
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
          _passwordCard(me),
        ]),
      ],
    );
  }
}
