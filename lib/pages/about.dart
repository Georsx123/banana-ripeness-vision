import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';
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

  Widget _row(IconData i, String t, String d) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, color: kDeepAmber, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: const TextStyle(fontWeight: FontWeight.w800, color: kBrown)),
              Text(d, style: TextStyle(color: Colors.brown.shade400, height: 1.4)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return PageWrap(
      title: 'Tentang Aplikasi',
      subtitle: 'Informasi, manfaat, dan kontak pengembang.',
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
              child: const Text('🍌', style: TextStyle(fontSize: 44)),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text(AppConfig.appName, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
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
        const SectionTitle('Manfaat aplikasi', Icons.volunteer_activism_rounded),
        AppCard(
          child: Column(children: [
            _row(Icons.shopping_basket_rounded, 'Memilih pisang saat berbelanja', 'Tahu mana pisang yang siap dimakan, perlu menunggu, atau sebaiknya dihindari.'),
            _row(Icons.storefront_rounded, 'Membantu pedagang & petani', 'Memilah pisang berdasarkan tingkat kematangan untuk menentukan waktu jual dan kualitas.'),
            _row(Icons.recycling_rounded, 'Mengurangi sampah makanan', 'Saran penanganan untuk pisang yang terlalu matang agar tidak terbuang percuma.'),
            _row(Icons.school_rounded, 'Belajar & edukasi', 'Wawasan seputar pisang lengkap dengan grafik dan fakta unik.'),
          ]),
        ),
        const SectionTitle('Cara menggunakan', Icons.menu_book_rounded),
        AppCard(
          child: Column(children: [
            _row(Icons.looks_one_rounded, 'Buka menu Scan', 'Pilih mode Input Gambar atau Realtime.'),
            _row(Icons.looks_two_rounded, 'Ambil atau pilih foto / aktifkan kamera', 'Pastikan pisang terlihat jelas dengan pencahayaan cukup.'),
            _row(Icons.looks_3_rounded, 'Lihat hasil', 'Kelas, akurasi, dan saran penanganan akan tampil. Hasil otomatis masuk ke Riwayat.'),
          ]),
        ),
        const SectionTitle('Informasi teknis', Icons.memory_rounded),
        AppCard(
          child: Column(children: [
            _row(Icons.psychology_rounded, 'Model AI', 'Roboflow, dilatih dengan 6 kelas: mentah, segar belum matang, segar matang, matang, terlalu matang, busuk.'),
            _row(Icons.storage_rounded, 'Database', 'Supabase (PostgreSQL) dengan 3 tabel: profiles, riwayat_scan, info_pisang.'),
            _row(Icons.flutter_dash_rounded, 'Platform', 'Flutter Web (PWA). Bisa dipasang ke layar utama HP lewat browser.'),
            _row(Icons.warning_amber_rounded, 'Catatan', 'Hasil deteksi adalah perkiraan AI dan dapat dipengaruhi cahaya serta sudut foto.'),
          ]),
        ),
        const SizedBox(height: 10),
        Center(child: Text('© 2026 ${AppConfig.appName}', style: TextStyle(color: Colors.brown.shade300))),
      ],
    );
  }
}
