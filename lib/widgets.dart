import 'package:flutter/material.dart';
import 'theme.dart';

Color alpha(Color c, double o) => c.withAlpha((o * 255).round());
String two(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime d) {
  final l = d.toLocal();
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}

/// Perpindahan halaman dengan efek memudar (dipakai untuk splash / login).
Route<T> fadeRoute<T>(Widget page, {int ms = 650}) => PageRouteBuilder<T>(
      transitionDuration: Duration(milliseconds: ms),
      reverseTransitionDuration: Duration(milliseconds: ms),
      pageBuilder: (context, animation, secondary) => page,
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut), child: child),
    );

void toast(BuildContext context, String msg, {bool error = false}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? Colors.red.shade700 : kGreen,
    behavior: SnackBarBehavior.floating,
  ));
}

Future<bool> confirmDialog(BuildContext context, String title, String message, {String okText = 'Ya', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(okText, style: TextStyle(color: danger ? Colors.red.shade700 : kDeepAmber, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Muncul perlahan (fade + geser) dengan jeda opsional.
class Reveal extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const Reveal({super.key, required this.child, this.delayMs = 0});
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero).animate(a),
        child: widget.child,
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kLine),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  const SectionTitle(this.text, this.icon, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 12),
      child: Row(children: [
        Icon(icon, color: kDeepAmber),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kBrown))),
      ]),
    );
  }
}

class PageWrap extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;
  const PageWrap({super.key, required this.title, this.subtitle, this.trailing, required this.children});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      padding: EdgeInsets.all(w < 600 ? 14 : 26),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kBrown)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(subtitle!, style: TextStyle(color: Colors.brown.shade400, fontSize: 14)),
                      ),
                  ]),
                ),
                if (trailing != null) trailing!,
              ]),
              const SizedBox(height: 18),
              for (var i = 0; i < children.length; i++)
                Reveal(
                  key: ValueKey('${children[i].runtimeType}-$i'),
                  delayMs: i < 8 ? i * 70 : 560,
                  child: children[i],
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menyusun anak-anak menjadi kolom responsif.
class ResponsiveWrap extends StatelessWidget {
  final List<Widget> children;
  final double minWidth;
  final double spacing;
  const ResponsiveWrap({super.key, required this.children, this.minWidth = 300, this.spacing = 14});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      var n = (c.maxWidth / minWidth).floor();
      if (n < 1) n = 1;
      if (n > children.length && children.isNotEmpty) n = children.length;
      final w = (c.maxWidth - spacing * (n - 1)) / n;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const StatCard({super.key, required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: alpha(color, .15), borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kBrown), overflow: TextOverflow.ellipsis),
            Text(label, style: TextStyle(color: Colors.brown.shade400, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

class PassField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;
  final TextInputAction action;
  const PassField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.onSubmitted,
    this.action = TextInputAction.next,
  });

  @override
  State<PassField> createState() => _PassFieldState();
}

class _PassFieldState extends State<PassField> {
  bool _hide = true;
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hide,
      validator: widget.validator,
      textInputAction: widget.action,
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _hide ? 'Tampilkan password' : 'Sembunyikan password',
          icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _hide = !_hide),
        ),
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onPressed;
  const AppButton({super.key, required this.label, this.icon, this.loading = false, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ]),
    );
  }
}

String? requiredValidator(String? v, [String name = 'Kolom ini']) =>
    (v == null || v.trim().isEmpty) ? '$name wajib diisi' : null;

/// Kerangka halaman login / registrasi / lupa password.
class AuthScaffold extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE9A8), kBg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(children: [
                  if (Navigator.canPop(context))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
                    ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.elasticOut,
                    builder: (context, v, child) => Transform.scale(scale: v, child: child),
                    child: Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: kLine, width: 2)),
                      child: const Text('🍌', style: TextStyle(fontSize: 38)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Reveal(
                    delayMs: 150,
                    child: AppCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kBrown)),
                        const SizedBox(height: 4),
                        Text(subtitle, style: TextStyle(color: Colors.brown.shade400)),
                        const SizedBox(height: 20),
                        child,
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
