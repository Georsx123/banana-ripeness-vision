import 'package:flutter/material.dart';
import '../config.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'about.dart';
import 'admin_info.dart';
import 'admin_stats.dart';
import 'admin_users.dart';
import 'dashboard.dart';
import 'history.dart';
import 'landing.dart';
import 'profile.dart';
import 'scan.dart';
import 'splash.dart';

class _Menu {
  final String title;
  final IconData icon;
  final Widget Function() builder;
  final bool admin;
  _Menu(this.title, this.icon, this.builder, {this.admin = false});
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;
  late final List<_Menu> _menus;

  @override
  void initState() {
    super.initState();
    final admin = AppState.me?.isAdmin ?? false;
    _menus = [
      _Menu('Dashboard', Icons.dashboard_rounded, () => DashboardPage(onGoto: _go)),
      _Menu('Scan', Icons.center_focus_strong_rounded, () => const ScanPage()),
      _Menu('Riwayat', Icons.history_rounded, () => const HistoryPage()),
      _Menu('Profil', Icons.person_rounded, () => const ProfilePage()),
      _Menu('About', Icons.info_rounded, () => const AboutPage()),
      if (admin) ...[
        _Menu('Statistik', Icons.analytics_rounded, () => const AdminStatsPage(), admin: true),
        _Menu('Kelola Pengguna', Icons.manage_accounts_rounded, () => const AdminUsersPage(), admin: true),
        _Menu('Kelola Info Pisang', Icons.edit_note_rounded, () => const AdminInfoPage(), admin: true),
      ],
    ];
  }

  void _go(int i) {
    if (i >= 0 && i < _menus.length) setState(() => _i = i);
  }

  void _select(int i) {
    final wide = MediaQuery.of(context).size.width >= 900;
    setState(() => _i = i);
    if (!wide) Navigator.pop(context);
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
      appBar: AppBar(title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w800))),
      drawer: Drawer(child: _sidebar()),
      body: body,
    );
  }
}
