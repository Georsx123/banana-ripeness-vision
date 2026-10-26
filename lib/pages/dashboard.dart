import 'package:flutter/material.dart';
import '../charts.dart';
import '../info_data.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class DashboardPage extends StatefulWidget {
  final void Function(int) onGoto;
  const DashboardPage({super.key, required this.onGoto});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> _scans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Api.refreshQuota();
    try {
      _scans = await Api.myScans();
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Satu kelas kematangan: ketuk untuk membuka detail, ketuk lagi untuk menutup.
  Widget _kelasTile(KelasInfo k) {
    final d = kelasDetail[k.key];
    return Collapsible(
      accent: k.warna,
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: alpha(k.warna, .2), shape: BoxShape.circle, border: Border.all(color: k.warna, width: 2.5)),
        child: const Text('\u{1F34C}', style: TextStyle(fontSize: 21)),
      ),
      title: k.nama,
      subtitle: k.deskripsi,
      children: [
        if (d != null) InfoBullet(judul: 'Ciri-ciri', isi: d.ciri, color: k.warna),
        InfoBullet(judul: 'Penjelasan', isi: k.deskripsi, color: k.warna),
        if (d != null) InfoBullet(judul: 'Cocok untuk', isi: d.cocok, color: k.warna),
        if (k.saran.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: alpha(kAmber, .15), borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.tips_and_updates_rounded, size: 20, color: kDeepAmber),
              const SizedBox(width: 8),
              Expanded(child: Text(k.saran, style: const TextStyle(height: 1.4, fontSize: 13.5))),
            ]),
          ),
      ],
    );
  }

  /// Satu kelompok wawasan (fakta, tips, sejarah, dan seterusnya) yang bisa dilipat.
  Widget _groupTile(InfoGroup g) {
    return Collapsible(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = AppState.me;
    final counts = classCounts(_scans);
    final now = DateTime.now();
    final today = distinctScans(_scans.where((s) {
      final d = DateTime.tryParse('${s['created_at']}')?.toLocal();
      return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
    }));
    String topKelas = '-';
    if (counts.isNotEmpty) {
      final e = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      topKelas = infoKelas(e.key).nama;
    }
    final wide = MediaQuery.of(context).size.width > 560;

    return PageWrap(
      title: 'Dashboard',
      subtitle: 'Ringkasan aktivitas dan wawasan seputar pisang.',
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFCA28), Color(0xFFEF6C00)]),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Halo, ${me?.nama ?? ''}! \u{1F44B}',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Sudah cek kematangan pisangmu hari ini? Arahkan kamera atau unggah foto, AI akan menjawabnya.',
                    style: TextStyle(color: Colors.white, height: 1.4)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kBrown),
                  onPressed: () => widget.onGoto(1),
                  icon: const Icon(Icons.center_focus_strong_rounded),
                  label: const Text('Mulai Scan'),
                ),
              ]),
            ),
            if (wide) const Padding(padding: EdgeInsets.only(left: 12), child: Text('\u{1F34C}', style: TextStyle(fontSize: 96))),
          ]),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
        else
          ResponsiveWrap(minWidth: 230, children: [
            StatCard(icon: Icons.qr_code_scanner_rounded, label: 'Total scan saya', value: '${distinctScans(_scans)}', color: kDeepAmber),
            StatCard(icon: Icons.today_rounded, label: 'Scan hari ini', value: '$today', color: kGreen),
            StatCard(icon: Icons.emoji_events_rounded, label: 'Kelas terbanyak', value: topKelas, color: const Color(0xFF8E24AA)),
            ValueListenableBuilder<Quota?>(
              valueListenable: Api.quota,
              builder: (_, q, __) {
                final admin = AppState.me?.isAdmin ?? false;
                final unlimited = admin || (q?.unlimited ?? false);
                final plan = admin ? 'Admin' : planInfo(q?.plan ?? AppState.me?.plan ?? 'reguler').nama;
                final habis = q != null && !unlimited && q.remaining <= 0;
                return StatCard(
                  icon: Icons.bolt_rounded,
                  label: 'Sisa scan hari ini \u2022 $plan',
                  value: unlimited ? 'Tanpa batas' : (q == null ? '...' : '${q.remaining} dari ${q.limit}'),
                  color: habis ? Colors.red.shade700 : const Color(0xFF1E88E5),
                );
              },
            ),
          ]),
        const SectionTitle('Enam tingkat kematangan', Icons.category_rounded),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Ketuk salah satu kelas untuk membuka detailnya, ketuk lagi untuk menutup.',
              style: TextStyle(color: Colors.brown.shade400, fontSize: 13)),
        ),
        ResponsiveWrap(minWidth: 340, children: [for (final k in kelasList) _kelasTile(k)]),
        const SectionTitle('Grafik & statistik', Icons.bar_chart_rounded),
        ResponsiveWrap(minWidth: 420, children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Pati menjadi gula saat pisang matang', style: TextStyle(fontWeight: FontWeight.w800, color: kBrown)),
              const SizedBox(height: 14),
              const StageLineChart(),
            ]),
          ),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Komposisi buah pisang', style: TextStyle(fontWeight: FontWeight.w800, color: kBrown)),
              const SizedBox(height: 14),
              const CompositionPie(),
            ]),
          ),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Pisang terdeteksi per kelas', style: TextStyle(fontWeight: FontWeight.w800, color: kBrown)),
              const SizedBox(height: 14),
              if (_scans.isEmpty)
                const SizedBox(height: 150, child: Center(child: Text('Belum ada scan. Coba menu Scan!')))
              else
                ClassBarChart(counts: counts),
            ]),
          ),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Proporsi hasil scan saya', style: TextStyle(fontWeight: FontWeight.w800, color: kBrown)),
              const SizedBox(height: 14),
              ClassPieChart(counts: counts),
            ]),
          ),
        ]),
        const SectionTitle('Wawasan seputar pisang', Icons.auto_awesome_rounded),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Ketuk judul untuk membuka atau menutup isinya.', style: TextStyle(color: Colors.brown.shade400, fontSize: 13)),
        ),
        Column(children: [
          for (final g in infoGroups) Padding(padding: const EdgeInsets.only(bottom: 12), child: _groupTile(g)),
        ]),
      ],
    );
  }
}
