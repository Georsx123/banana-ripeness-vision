import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services.dart';
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

/// Kontrol halaman tabel: pilihan jumlah per halaman (opsional), info "a-b dari n", dan tombol sebelumnya/berikutnya.
class PagerBar extends StatelessWidget {
  final int total, page, perPage; // page dimulai dari 0
  final ValueChanged<int> onPage;
  final List<int>? perPageOptions; // null = jumlah per halaman tetap (tanpa pilihan)
  final ValueChanged<int>? onPerPage;
  const PagerBar({
    super.key,
    required this.total,
    required this.page,
    required this.perPage,
    required this.onPage,
    this.perPageOptions,
    this.onPerPage,
  });

  @override
  Widget build(BuildContext context) {
    final pages = total == 0 ? 1 : (total + perPage - 1) ~/ perPage;
    final from = total == 0 ? 0 : page * perPage + 1;
    final to = (page + 1) * perPage > total ? total : (page + 1) * perPage;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        if (perPageOptions != null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Tampilkan ', style: TextStyle(fontSize: 13, color: kBrown)),
            DropdownButton<int>(
              value: perPage,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: [for (final o in perPageOptions!) DropdownMenuItem<int>(value: o, child: Text('$o'))],
              onChanged: (v) {
                if (v != null) onPerPage?.call(v);
              },
            ),
            const Text(' per halaman', style: TextStyle(fontSize: 13, color: kBrown)),
          ]),
        Text('$from\u2013$to dari $total', style: TextStyle(fontSize: 13, color: Colors.brown.shade400)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Sebelumnya',
            onPressed: page > 0 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text('${page + 1} / $pages', style: const TextStyle(fontWeight: FontWeight.w700, color: kBrown)),
          IconButton(
            tooltip: 'Berikutnya',
            onPressed: page < pages - 1 ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
      ],
    );
  }
}

/// Kartu yang bisa dibuka dan ditutup dengan animasi geser (hemat ruang di layar HP).
class Collapsible extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final bool initiallyExpanded;
  final Color? accent;
  final List<Widget> children;
  const Collapsible({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.initiallyExpanded = false,
    this.accent,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? kDeepAmber;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: kLine)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedAlignment: Alignment.centerLeft,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            shape: const Border(),
            collapsedShape: const Border(),
            iconColor: color,
            collapsedIconColor: kBrown,
            textColor: kBrown,
            collapsedTextColor: kBrown,
            leading: leading,
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            subtitle: subtitle == null
                ? null
                : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.brown.shade400, fontSize: 12.5)),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Butir informasi: titik berwarna + judul tebal + isi.
class InfoBullet extends StatelessWidget {
  final String judul;
  final String isi;
  final Color color;
  const InfoBullet({super.key, required this.judul, required this.isi, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 7, right: 10), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(judul, style: const TextStyle(fontWeight: FontWeight.w800, color: kBrown, height: 1.3)),
            const SizedBox(height: 2),
            Text(isi, style: TextStyle(color: Colors.brown.shade600, height: 1.45, fontSize: 13.5)),
          ]),
        ),
      ]),
    );
  }
}

class FOpt {
  final String value;
  final String label;
  const FOpt(this.value, this.label);
}

/// true bila tanggal [t] berada dalam rentang [r] (r null = tanpa filter tanggal).
bool inDateRange(DateTime t, DateTimeRange? r) {
  if (r == null) return true;
  final l = t.toLocal();
  final d = DateTime(l.year, l.month, l.day);
  final a = DateTime(r.start.year, r.start.month, r.start.day);
  final b = DateTime(r.end.year, r.end.month, r.end.day);
  return !d.isBefore(a) && !d.isAfter(b);
}

/// Pilihan filter (dropdown) berlabel.
class FilterDrop extends StatelessWidget {
  final String label;
  final String value;
  final List<FOpt> options;
  final ValueChanged<String> onChanged;
  const FilterDrop({super.key, required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final safe = options.any((o) => o.value == value) ? value : options.first.value;
    return SizedBox(
      width: 185,
      child: DropdownButtonFormField<String>(
        initialValue: safe,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        items: [for (final o in options) DropdownMenuItem<String>(value: o.value, child: Text(o.label, overflow: TextOverflow.ellipsis))],
        onChanged: (v) => onChanged(v ?? options.first.value),
      ),
    );
  }
}

/// Bilah pencarian + filter + rentang tanggal untuk tabel.
class FilterBar extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onSearch;
  final List<Widget> filters;
  final DateTimeRange? range;
  final ValueChanged<DateTimeRange?>? onRange;
  final VoidCallback? onReset;
  const FilterBar({
    super.key,
    required this.hint,
    required this.onSearch,
    this.filters = const [],
    this.range,
    this.onRange,
    this.onReset,
  });

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _d(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final r = widget.range;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: _c,
            onChanged: (v) {
              widget.onSearch(v);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: _c.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _c.clear();
                        widget.onSearch('');
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        ...widget.filters,
        if (widget.onRange != null)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                initialDateRange: r,
              );
              if (picked != null) widget.onRange!(picked);
            },
            icon: const Icon(Icons.date_range_rounded, size: 18),
            label: Text(r == null ? 'Rentang tanggal' : '${_d(r.start)} - ${_d(r.end)}'),
          ),
        if (r != null && widget.onRange != null)
          IconButton(tooltip: 'Hapus filter tanggal', icon: const Icon(Icons.close_rounded), onPressed: () => widget.onRange!(null)),
        if (widget.onReset != null)
          TextButton.icon(
            onPressed: () {
              _c.clear();
              setState(() {});
              widget.onReset!();
            },
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset'),
          ),
      ]),
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

String? emailValidator(String? v) {
  final s = (v ?? '').trim().toLowerCase();
  if (!RegExp(r'^[a-z0-9._%+\-]+@([a-z0-9\-]+\.)+[a-z]{2,10}$').hasMatch(s)) return 'Format email tidak valid';
  // Cegah salah ketik domain populer, misalnya gmail.comm atau gmial.com
  final domain = s.split('@').last;
  const known = <String, List<String>>{
    'gmail': ['gmail.com'],
    'yahoo': ['yahoo.com', 'yahoo.co.id', 'yahoo.co.uk'],
    'hotmail': ['hotmail.com'],
    'outlook': ['outlook.com', 'outlook.co.id'],
    'icloud': ['icloud.com'],
  };
  final ok = known[domain.split('.').first];
  if (ok != null && !ok.contains(domain)) return 'Maksud kamu ${ok.first}?';
  if (domain == 'gmial.com' || domain == 'gmai.com' || domain == 'gmal.com' || domain == 'gamil.com') return 'Maksud kamu gmail.com?';
  return null;
}

/// Kolom kode OTP (angka saja, rata tengah).
class OtpField extends StatelessWidget {
  final TextEditingController controller;
  const OtpField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 10,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w800),
      decoration: const InputDecoration(labelText: 'Kode OTP dari email', counterText: ''),
      validator: (v) => (v ?? '').trim().length < 6 ? 'Masukkan kode OTP dari email' : null,
    );
  }
}

/// Dua kolom password baru + konfirmasi, dengan tombol mata (tampilkan/sembunyikan).
class PasswordPair extends StatefulWidget {
  final TextEditingController p1, p2;
  final String label;
  const PasswordPair({super.key, required this.p1, required this.p2, this.label = 'Password baru'});

  @override
  State<PasswordPair> createState() => _PasswordPairState();
}

class _PasswordPairState extends State<PasswordPair> {
  bool _hide = true;

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _hide ? 'Tampilkan password' : 'Sembunyikan password',
          icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _hide = !_hide),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
        controller: widget.p1,
        obscureText: _hide,
        textInputAction: TextInputAction.next,
        decoration: _dec(widget.label),
        validator: (v) => (v ?? '').length < 6 ? 'Minimal 6 karakter' : null,
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: widget.p2,
        obscureText: _hide,
        decoration: _dec('Konfirmasi ${widget.label.toLowerCase()}'),
        validator: (v) => v != widget.p1.text ? 'Konfirmasi tidak sama' : null,
      ),
    ]);
  }
}

/// Lencana tipe user (Reguler / VIP / Premium) atau Admin.
class PlanBadge extends StatelessWidget {
  final String plan;
  final bool admin;
  const PlanBadge({super.key, required this.plan, this.admin = false});

  @override
  Widget build(BuildContext context) {
    final p = planInfo(plan);
    final color = admin ? kGreen : p.warna;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: alpha(color, .15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: alpha(color, .6)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(admin ? Icons.shield_rounded : p.ikon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(admin ? 'Admin' : p.nama, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: color)),
      ]),
    );
  }
}

/// Kotak ringkas: tipe user + sisa scan hari ini.
class QuotaBar extends StatelessWidget {
  const QuotaBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Quota?>(
      valueListenable: Api.quota,
      builder: (context, q, _) {
        final me = AppState.me;
        final isAdmin = me?.isAdmin ?? false;
        final unlimited = isAdmin || (q?.unlimited ?? false);
        final plan = q?.plan ?? me?.plan ?? 'reguler';
        final remaining = q?.remaining ?? 0;
        final limit = q?.limit ?? 0;
        final exhausted = q != null && !unlimited && remaining <= 0;
        final color = exhausted ? Colors.red.shade700 : kDeepAmber;
        return AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              PlanBadge(plan: plan, admin: isAdmin),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  unlimited ? 'Scan tanpa batas' : (q == null ? 'Memuat sisa scan...' : 'Sisa scan hari ini: $remaining dari $limit'),
                  style: TextStyle(fontWeight: FontWeight.w800, color: exhausted ? Colors.red.shade700 : kBrown),
                ),
              ),
            ]),
            if (!unlimited && q != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: limit == 0 ? 0 : remaining / limit,
                  minHeight: 8,
                  color: color,
                  backgroundColor: alpha(color, .15),
                ),
              ),
            ],
            if (exhausted) ...[
              const SizedBox(height: 8),
              Text(
                'Batas scan hari ini sudah habis. Scan aktif lagi besok. Hubungi admin untuk upgrade paket.',
                style: TextStyle(color: Colors.red.shade700, fontSize: 12.5, height: 1.35),
              ),
            ],
          ]),
        );
      },
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
