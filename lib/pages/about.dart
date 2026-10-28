import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import '../info_data.dart';
import '../theme.dart';
import '../widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _copy(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) toast(context, '$label disalin');
  }

  Widget _contact(BuildContext context, IconData icon, String label, String value, Color color) {
    return AppCard(
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: alpha(color, .15), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: Colors.brown.shade400, fontSize: 12.5)),
            SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w800, color: kBrown, fontSize: 15)),
          ]),
        ),
        IconButton.filledTonal(
          tooltip: 'Salin',
          onPressed: () => _copy(context, value, label),
          icon: const Icon(Icons.copy_rounded, size: 20),
        ),
      ]),
    );
  }

  Widget _group(InfoGroup g) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Collapsible(
        accent: g.warna,
        initiallyExpanded: g.terbuka,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: alpha(g.warna, .15), borderRadius: BorderRadius.circular(14)),
          child: Icon(g.ikon, color: g.warna),
        ),
        title: g.judul,
        subtitle: g.ringkas,
        children: [for (final i in g.items) InfoBullet(judul: i.judul, isi: i.isi, color: g.warna)],
      ),
    );
  }

  /// Daftar enam kelas yang dikenali model.
  Widget _kelasGroup() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Collapsible(
        accent: kDeepAmber,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: alpha(kAmber, .2), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.category_rounded, color: kDeepAmber),
        ),
        title: 'Enam kelas yang dikenali',
        subtitle: 'Dari mentah sampai busuk',
        children: [for (final k in kelasList) InfoBullet(judul: k.nama, isi: k.deskripsi, color: k.warna)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageWrap(
      title: 'Tentang Aplikasi',
      subtitle: 'Informasi, cara pakai, model AI, dan kontak pengembang.',
      children: [
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFCA28), Color(0xFFEF6C00)]),
          ),
          child: Row(children: [
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: BananaImage(size: 44),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text(AppConfig.appName, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
                const SizedBox(height: 2),
                const Text('Deteksi kematangan pisang berbasis AI', style: TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(70), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Versi ${AppConfig.appVersion}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ]),
        ),
        const SectionTitle('Kontak', Icons.contact_support_rounded),
        ResponsiveWrap(minWidth: 380, children: [
          _contact(context, Icons.email_rounded, 'Email', AppConfig.contactEmail, const Color(0xFFD32F2F)),
          _contact(context, Icons.chat_rounded, 'WhatsApp', AppConfig.contactWa, kGreen),
        ]),
        const SectionTitle('Informasi lengkap', Icons.menu_book_rounded),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Ketuk judul untuk membuka atau menutup isinya.', style: TextStyle(color: Colors.brown.shade400, fontSize: 13)),
        ),
        Column(children: [
          for (final g in aboutAtas) _group(g),
          _kelasGroup(),
          for (final g in aboutBawah) _group(g),
        ]),
        const SizedBox(height: 6),
        Center(child: Text('\u00a9 2026 ${AppConfig.appName}', style: TextStyle(color: Colors.brown.shade300))),
      ],
    );
  }
}
