import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'about.dart';
import 'admin_log.dart';
import 'admin_pesan.dart';
import 'admin_settings.dart';
import 'admin_stats.dart';
import 'admin_users.dart';
import 'dashboard.dart';
import 'history.dart';
import 'landing.dart';
import 'offer_dialog.dart';
import 'plan_page.dart';
import 'profile.dart';
import 'scan.dart';
import 'splash.dart';

class _Menu {
  final String title;
  final IconData icon;
  final Widget Function() builder;
  final bool admin;
  final bool badge; // tampilkan titik notifikasi pesan
  _Menu(this.title, this.icon, this.builder, {this.admin = false, this.badge = false});
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;
  late final List<_Menu> _menus;
  Timer? _pollTimer;
  int _lastPerlu = 0;
  int _lastSetuju = 0;
  bool _pollInit = false;

  @override
  void initState() {
    super.initState();
    Api.maintenance().then((_) {}, onError: (_) {}); // siapkan status pemeliharaan sebelum menu Scan dibuka
    Api.refreshQuota();
    // Setelah login: tampilkan jendela penawaran paket (hanya untuk user biasa).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !AppState.showOffer) return;
      AppState.showOffer = false;
      final me = AppState.me;
      if (me == null || me.isAdmin) return;
      await showOfferDialog(context, me.plan);
    });
    final admin = AppState.me?.isAdmin ?? false;
    _menus = [
      _Menu('Dashboard', Icons.dashboard_rounded, () => DashboardPage(onGoto: _go)),
      _Menu('Scan', Icons.center_focus_strong_rounded, () => const ScanPage()),
      _Menu('Riwayat', Icons.history_rounded, () => const HistoryPage()),
      _Menu('Plan', Icons.workspace_premium_rounded, () => const PlanPage()),
      _Menu('Profil', Icons.person_rounded, () => const ProfilePage()),
      _Menu('About', Icons.info_rounded, () => const AboutPage()),
      if (admin) ...[
        _Menu('Statistik', Icons.analytics_rounded, () => const AdminStatsPage(), admin: true),
        _Menu('Kelola Pengguna', Icons.manage_accounts_rounded, () => const AdminUsersPage(), admin: true),
        _Menu('Pesan', Icons.sticky_note_2_rounded, () => const AdminPesanPage(), admin: true, badge: true),
        _Menu('Aktivitas Admin', Icons.history_edu_rounded, () => const AdminLogPage(), admin: true),
        _Menu('Pengaturan', Icons.tune_rounded, () => const AdminSettingsPage(), admin: true),
      ],
    ];
    if (admin) {
      _pollPesan();
      _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollPesan());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Cek pesan/permintaan baru secara berkala (khusus admin) untuk titik notifikasi.
  Future<void> _pollPesan() async {
    final m = await Api.refreshPesanSummary();
    if (!mounted || m.isEmpty) return;
    final perlu = m['perlu_tindakan'] ?? 0;
    final setuju = m['disetujui_saya'] ?? 0;
    if (_pollInit) {
      if (setuju > _lastSetuju) {
        toast(context, 'Permintaan izinmu disetujui. Buka menu Pesan, lalu ulangi aksinya.');
      } else if (perlu > _lastPerlu) {
        toast(context, 'Ada permintaan izin baru di menu Pesan.');
      }
    }
    _lastPerlu = perlu;
    _lastSetuju = setuju;
    _pollInit = true;
  }

  void _go(int i) {
    if (i >= 0 && i < _menus.length) setState(() => _i = i);
  }

  void _select(int i) {
    final wide = MediaQuery.of(context).size.width >= 900;
    setState(() => _i = i);
    if (!wide) Navigator.pop(context);
    if (AppState.me?.isAdmin == true) Api.refreshPesanSummary();
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(context, 'Keluar', 'Yakin ingin keluar dari akun?', okText: 'Keluar', danger: true);
    if (!ok) return;
    await Api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute(BrandSplash(
        title: 'Sampai jumpa!',
        subtitle: 'Terima kasih sudah memakai aplikasi ini.',
        duration: SplashTiming.afterLogout,
        onDone: (ctx) => Navigator.of(ctx).pushReplacement(fadeRoute(const LandingPage())),
      )),
      (r) => false,
    );
  }

  Widget _sidebar() {
    final firstAdmin = _menus.indexWhere((m) => m.admin);
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Column(children: [
          ValueListenableBuilder<Profile?>(
            valueListenable: AppState.notifier,
            builder: (_, p, __) {
              final nama = p?.nama ?? '-';
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFCA28), Color(0xFFF57C00)]),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(nama.isEmpty ? '?' : nama.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kDeepAmber)),
                  ),
                  const SizedBox(height: 12),
                  Text(nama, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('@${p?.username ?? ''}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(70), borderRadius: BorderRadius.circular(20)),
                    child: Text(p?.isAdmin == true ? 'Admin' : 'Pengguna',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ]),
              );
            },
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(12), children: [
              for (var i = 0; i < _menus.length; i++) ...[
                if (i == firstAdmin)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
                    child: Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.brown.shade300, fontSize: 12.5)),
                  ),
                ListTile(
                  selected: i == _i,
                  selectedColor: kDeepAmber,
                  selectedTileColor: alpha(kAmber, .18),
                  iconColor: kBrown,
                  textColor: kBrown,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: Icon(_menus[i].icon),
                  title: Text(_menus[i].title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: _menus[i].badge
                      ? ValueListenableBuilder<bool>(
                          valueListenable: Api.pesanDot,
                          builder: (_, v, __) => v
                              ? Container(
                                  width: 11,
                                  height: 11,
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                )
                              : const SizedBox.shrink(),
                        )
                      : null,
                  onTap: () => _select(i),
                ),
              ],
            ]),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              leading: Icon(Icons.logout_rounded, color: Colors.red.shade700),
              title: Text('Keluar', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)),
              subtitle: Text('v${AppConfig.appVersion}', style: const TextStyle(fontSize: 11)),
              onTap: _logout,
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final m = _menus[_i];
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(_i), child: m.builder()),
    );
    if (wide) {
      return Scaffold(
        body: Row(children: [
          SizedBox(width: 280, child: _sidebar()),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: Api.pesanDot,
            builder: (_, v, __) {
              final idx = _menus.indexWhere((x) => x.badge);
              if (!v || idx < 0) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Ada pesan baru',
                icon: Stack(children: [
                  const Icon(Icons.sticky_note_2_rounded),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                  ),
                ]),
                onPressed: () => _go(idx),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(child: _sidebar()),
      body: body,
    );
  }
}
