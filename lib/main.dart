import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'services.dart';
import 'theme.dart';
import 'pages/landing.dart';
import 'pages/shell.dart';
import 'pages/splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? initError;
  try {
    await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  } catch (e) {
    initError = e.toString();
  }
  runApp(PisangApp(initError: initError));
}

class PisangApp extends StatelessWidget {
  final String? initError;
  const PisangApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) {
    Route<dynamic> rootRoute() => MaterialPageRoute(builder: (_) => Root(initError: initError));
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Link dari email (verifikasi) bisa membawa tambahan di alamat; semuanya diarahkan ke halaman utama.
      onGenerateInitialRoutes: (String name) => [rootRoute()],
      onUnknownRoute: (settings) => rootRoute(),
    );
  }
}

class Root extends StatefulWidget {
  final String? initError;
  const Root({super.key, this.initError});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  late final Future<bool> _f = _check();
  final String? _notice = _linkNotice();

  /// Mengenali pengguna yang baru membuka link dari email (verifikasi) dan menyiapkan pesan.
  static String? _linkNotice() {
    final u = Uri.base;
    final frag = u.fragment;
    final q = u.queryParameters;
    if (q.containsKey('error_description') || frag.contains('error_description') || frag.contains('otp_expired')) {
      return 'ERR:Link verifikasi tidak valid atau sudah kedaluwarsa. Minta email verifikasi baru lewat halaman Masuk.';
    }
    if (q.containsKey('code') || frag.contains('type=signup') || frag.contains('access_token')) {
      return 'OK:Email berhasil diverifikasi. Silakan masuk.';
    }
    return null;
  }

  /// Menunggu pengecekan sesi DAN minimal SplashTiming.startup (lihat splash.dart).
  Future<bool> _check() async {
    final r = await Future.wait<Object?>([
      _load(),
      Future<void>.delayed(SplashTiming.startup),
    ]);
    return r[0] == true;
  }

  Future<bool> _load() async {
    if (widget.initError != null) return false;
    try {
      if (sb.auth.currentSession == null) return false;
      final p = await Api.loadProfile();
      if (p == null) {
        await sb.auth.signOut();
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.settings_suggest_rounded, size: 60, color: kDeepAmber),
              const SizedBox(height: 12),
              const Text('Konfigurasi belum benar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Periksa supabaseUrl dan supabaseAnonKey di lib/config.dart.', textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
    }
    return FutureBuilder<bool>(
      future: _f,
      builder: (context, snap) {
        final ready = snap.connectionState == ConnectionState.done;
        final Widget child;
        if (!ready) {
          child = const BrandSplash(key: ValueKey('splash'), title: AppConfig.appName, subtitle: 'Kenali kematangan pisang dalam sekejap');
        } else if (snap.data == true) {
          child = const Shell(key: ValueKey('shell'));
        } else {
          child = LandingPage(key: const ValueKey('landing'), notice: _notice);
        }
        return AnimatedSwitcher(duration: const Duration(milliseconds: 800), child: child);
      },
    );
  }
}
