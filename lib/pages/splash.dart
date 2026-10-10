import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets.dart';

/// =====================================================================
/// PENGATURAN DURASI LAYAR PEMBUKA - ubah angka di sini (satuan milidetik).
/// 1000 = 1 detik. Setelah mengubah, tekan R (huruf besar) di terminal.
/// =====================================================================
class SplashTiming {
  /// Saat aplikasi pertama dibuka (sebelum halaman awal).
  static const startup = Duration(milliseconds: 4000);

  /// Setelah klik Masuk (sebelum dashboard). Ditambah +0,6 detik animasi masuk.
  static const afterLogin = Duration(milliseconds: 3000);

  /// Setelah klik Keluar (sebelum halaman awal). Ditambah +0,6 detik animasi masuk.
  static const afterLogout = Duration(milliseconds: 3000);
}

/// Layar pembuka bermerek: dipakai saat aplikasi dibuka dan setelah login.
/// - Tanpa [onDone]  : progress berputar terus (menunggu proses lain selesai).
/// - Dengan [onDone] : progress terisi selama [duration], lalu memanggil [onDone].
class BrandSplash extends StatefulWidget {
  final String title;
  final String subtitle;
  final Duration duration;
  final void Function(BuildContext context)? onDone;
  const BrandSplash({
    super.key,
    required this.title,
    this.subtitle = '',
    this.duration = SplashTiming.afterLogin,
    this.onDone,
  });

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  late final AnimationController _prog = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.onDone != null) {
      // Progres baru mulai setelah animasi masuk (logo, judul) selesai, supaya tidak terasa singkat.
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        _prog.forward().whenComplete(() {
          if (mounted) widget.onDone!(context);
        });
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _prog.dispose();
    super.dispose();
  }

  Widget _floating(BoxConstraints c, double fx, double fy, double size, double phase) {
    return Positioned(
      left: c.maxWidth * fx,
      top: c.maxHeight * fy,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = (_pulse.value + phase) % 1.0;
            return Transform.translate(
              offset: Offset(0, math.sin(t * 2 * math.pi) * 12),
              child: Transform.rotate(
                angle: math.sin(t * 2 * math.pi) * 0.25,
                child: Opacity(opacity: 0.5, child: Text('🍌', style: TextStyle(fontSize: size))),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _logo() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final p = (_pulse.value * 2) % 1.0;
          final bob = math.sin(_pulse.value * 2 * math.pi * 2) * 0.12;
          return SizedBox(
            width: 190,
            height: 190,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                width: 120 + 70 * p,
                height: 120 + 70 * p,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha((130 * (1 - p)).round()), width: 3),
                ),
              ),
              Container(
                width: 120,
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(55), blurRadius: 30, offset: const Offset(0, 14))],
                ),
                child: Transform.rotate(angle: bob, child: const Text('🍌', style: TextStyle(fontSize: 64))),
              ),
            ]),
          );
        },
      ),
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
            _floating(c, .08, .12, 42, 0.0),
            _floating(c, .84, .20, 34, .3),
            _floating(c, .12, .78, 38, .6),
            _floating(c, .84, .72, 48, .85),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _logo(),
                  const SizedBox(height: 6),
                  Reveal(
                    delayMs: 350,
                    child: Text(widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                  ),
                  if (widget.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Reveal(
                      delayMs: 550,
                      child: Text(widget.subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, color: Colors.white70)),
                    ),
                  ],
                  const SizedBox(height: 26),
                  Reveal(
                    delayMs: 700,
                    child: SizedBox(
                      width: 220,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedBuilder(
                          animation: _prog,
                          builder: (context, _) => LinearProgressIndicator(
                            value: widget.onDone == null ? null : Curves.easeInOut.transform(_prog.value),
                            minHeight: 7,
                            color: Colors.white,
                            backgroundColor: Colors.white.withAlpha(70),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}
