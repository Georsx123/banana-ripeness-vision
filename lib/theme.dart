import 'package:flutter/material.dart';

const kAmber = Color(0xFFF9A825);
const kDeepAmber = Color(0xFFE08A00);
const kBrown = Color(0xFF4E342E);
const kGreen = Color(0xFF2E7D32);
const kBg = Color(0xFFFFFBF0);
const kLine = Color(0xFFE9DFC8);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kAmber).copyWith(
    primary: kDeepAmber,
    onPrimary: Colors.white,
    secondary: kGreen,
  );
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    pageTransitionsTheme: PageTransitionsTheme(builders: <TargetPlatform, PageTransitionsBuilder>{
      for (final p in TargetPlatform.values) p: const SmoothTransitions(),
    }),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: kBrown,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border(kLine),
      enabledBorder: border(kLine),
      focusedBorder: border(kDeepAmber, 2),
      errorBorder: border(Colors.red.shade400),
      focusedErrorBorder: border(Colors.red.shade400, 2),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kDeepAmber,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kBrown,
        minimumSize: const Size(0, 50),
        side: const BorderSide(color: kLine, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

/// Informasi tiap kelas hasil model Roboflow.
class KelasInfo {
  final String key;
  final String nama;
  final String short;
  final String deskripsi;
  final String saran;
  final Color warna;
  const KelasInfo(this.key, this.nama, this.short, this.deskripsi, this.saran, this.warna);
}

const List<KelasInfo> kelasList = [
  KelasInfo('unripe', 'Mentah', 'Mentah',
      'Kulit masih hijau dan keras. Kandungan pati tinggi dan rasanya sepat.',
      'Simpan di suhu ruang 3-5 hari sampai menguning. Cocok untuk diolah jadi keripik atau pisang goreng tepung.',
      Color(0xFF7CB342)),
  KelasInfo('freshunripe', 'Segar Belum Matang', 'Segar\nBelum\nMatang',
      'Pisang baru dipetik dan masih segar, tetapi belum siap dimakan.',
      'Biarkan matang alami 2-3 hari. Jauhkan dari kulkas agar proses pematangan tidak terhambat.',
      Color(0xFFFF9800)),
  KelasInfo('freshripe', 'Segar Matang', 'Segar\nMatang',
      'Pisang segar dan baru matang. Kulit cerah, tekstur padat, rasa manis seimbang.',
      'Waktu terbaik untuk dimakan langsung. Bisa disimpan 1-2 hari lagi di suhu ruang.',
      Color(0xFF7C4DFF)),
  KelasInfo('ripe', 'Matang', 'Matang',
      'Kulit kuning merata, daging lembut dan manis. Siap dikonsumsi.',
      'Segera dimakan, atau simpan di kulkas (kulit akan menghitam tetapi daging tetap baik).',
      Color(0xFFE91EE0)),
  KelasInfo('overripe', 'Terlalu Matang', 'Terlalu\nMatang',
      'Banyak bintik cokelat, daging sangat lunak dan sangat manis.',
      'Ideal untuk banana bread, pancake, atau smoothie. Bisa dibekukan agar awet.',
      Color(0xFF00BFA5)),
  KelasInfo('rotten', 'Busuk', 'Busuk',
      'Kulit menghitam, berair atau berjamur, dan beraroma tidak sedap.',
      'Jangan dikonsumsi. Buang atau jadikan kompos.',
      Color(0xFFB0B800)),
];

KelasInfo infoKelas(String key) {
  final k = key.trim().toLowerCase().replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '');
  for (final i in kelasList) {
    if (i.key == k) return i;
  }
  return KelasInfo(key, key, key, 'Kelas tidak dikenal.', '', Colors.grey);
}

/// Transisi antar halaman: memudar + bergeser halus ke atas.
class SmoothTransitions extends PageTransitionsBuilder {
  const SmoothTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

/// Paket user (tipe akun) dan batas scan per hari. Admin tidak dibatasi.
class PlanInfo {
  final String key, nama, harga;
  final int limit;
  final Color warna;
  final IconData ikon;
  const PlanInfo(this.key, this.nama, this.limit, this.harga, this.warna, this.ikon);
}

const List<PlanInfo> planList = [
  PlanInfo('reguler', 'Reguler', 10, 'Gratis', Color(0xFF78909C), Icons.person_rounded),
  PlanInfo('vip', 'VIP', 50, 'Berbayar', Color(0xFFF9A825), Icons.workspace_premium_rounded),
  PlanInfo('premium', 'Premium', 100, 'Berbayar', Color(0xFF8E24AA), Icons.diamond_rounded),
];

PlanInfo planInfo(String key) {
  final k = key.trim().toLowerCase();
  for (final p in planList) {
    if (p.key == k) return p;
  }
  return planList.first;
}
