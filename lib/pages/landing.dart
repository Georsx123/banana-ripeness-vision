import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets.dart';
import 'login.dart';
import 'register.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

  static const _stages = <(String, Color)>[
    ('Mentah', Color(0xFF7CB342)),
    ('Segar\nBelum\nMatang', Color(0xFFC0CA33)),
    ('Segar\nMatang', Color(0xFFFDD835)),
    ('Matang', Color(0xFFFFB300)),
    ('Terlalu\nMatang', Color(0xFF8D6E63)),
    ('Busuk', Color(0xFF4E342E)),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bubble(BoxConstraints c, double fx, double fy, double size, double phase) {
    return Positioned(
      left: c.maxWidth * fx,
      top: c.maxHeight * fy,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = (_c.value + phase) % 1.0;
            return Transform.translate(
              offset: Offset(math.sin(t * 2 * math.pi) * 18, math.cos(t * 2 * math.pi) * 18),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(28)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _floating(BoxConstraints c, double fx, double fy, double size, double phase) {
    return Positioned(
      left: c.maxWidth * fx,
      top: c.maxHeight * fy,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = (_c.value + phase) % 1.0;
            return Transform.translate(
              offset: Offset(0, math.sin(t * 2 * math.pi) * 14),
              child: Transform.rotate(
                angle: math.sin(t * 2 * math.pi) * 0.25,
                child: Opacity(opacity: 0.55, child: Text('🍌', style: TextStyle(fontSize: size))),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _logo() {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final p = (_c.value * 4) % 1.0;
        final bob = math.sin(_c.value * 2 * math.pi * 2) * 0.12;
        return SizedBox(
          width: 200,
          height: 200,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 130 + 70 * p,
              height: 130 + 70 * p,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha((130 * (1 - p)).round()), width: 3),
              ),
            ),
            Container(
              width: 130,
              height: 130,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(55), blurRadius: 30, offset: const Offset(0, 14))],
              ),
              child: Transform.rotate(angle: bob, child: const Text('🍌', style: TextStyle(fontSize: 70))),
            ),
          ]),
        );
      },
    );
  }

  Widget _chip(IconData i, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withAlpha(60), borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _stageStrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(90)),
      ),
      child: Column(children: [
        const Text('Dari mentah sampai busuk, dikenali AI',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < _stages.length; i++)
            Expanded(
              child: Reveal(
                delayMs: 650 + i * 90,
                child: Column(children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _stages[i].$2,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 6, offset: const Offset(0, 3))],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_stages[i].$1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, height: 1.15)),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD54F), Color(0xFFFFA000), Color(0xFFE65100)],
          ),
        ),
        child: LayoutBuilder(builder: (context, c) {
          return Stack(fit: StackFit.expand, children: [
            _bubble(c, .78, .04, 220, 0.0),
            _bubble(c, -.12, .50, 260, .5),
            _bubble(c, .66, .82, 190, .25),
            _floating(c, .07, .10, 46, 0.0),
            _floating(c, .84, .22, 34, .3),
            _floating(c, .10, .80, 40, .6),
            _floating(c, .86, .68, 52, .85),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Reveal(child: _logo()),
                      const SizedBox(height: 4),
                      Reveal(
                        delayMs: 200,
                        child: Text(AppConfig.appName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 34, height: 1.1, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                      ),
                      const SizedBox(height: 8),
                      const Reveal(
                        delayMs: 320,
                        child: Text('Kenali tingkat kematangan pisang\ndalam sekali jepret dengan AI.',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white, height: 1.4)),
                      ),
                      const SizedBox(height: 20),
                      Reveal(
                        delayMs: 440,
                        child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                          _chip(Icons.category_rounded, '6 tingkat kematangan'),
                          _chip(Icons.photo_camera_rounded, 'Gambar & realtime'),
                          _chip(Icons.insights_rounded, 'Riwayat & grafik'),
                        ]),
                      ),
                      const SizedBox(height: 22),
                      Reveal(delayMs: 560, child: _stageStrip()),
                      const SizedBox(height: 28),
                      Reveal(
                        delayMs: 1000,
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kBrown, minimumSize: const Size(0, 54)),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage())),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('Masuk'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Reveal(
                        delayMs: 1100,
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 54),
                              side: const BorderSide(color: Colors.white, width: 2),
                            ),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Daftar Akun Baru'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Reveal(
                        delayMs: 1200,
                        child: Text('Versi ${AppConfig.appVersion}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}
