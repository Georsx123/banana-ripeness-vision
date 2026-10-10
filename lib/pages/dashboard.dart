import 'package:flutter/material.dart';
import '../charts.dart';
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
  List<Map<String, dynamic>> _infos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Api.myScans(), Api.infoAktif()]);
      _scans = r[0];
      _infos = r[1];
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  static const _fallback = [
    {'kategori': 'fakta', 'judul': 'Pisang itu buah berry', 'isi': 'Secara botani, pisang termasuk buah berry.'},
    {'kategori': 'info', 'judul': 'Pati berubah jadi gula', 'isi': 'Makin matang, pisang makin manis dan mudah dicerna.'},
    {'kategori': 'tips', 'judul': 'Perlambat pematangan', 'isi': 'Bungkus tangkai pisang dengan plastik wrap.'},
  ];

  IconData _icon(String k) => k == 'fakta' ? Icons.lightbulb_rounded : (k == 'tips' ? Icons.tips_and_updates_rounded : Icons.info_rounded);
  Color _color(String k) => k == 'fakta' ? const Color(0xFF8E24AA) : (k == 'tips' ? kGreen : const Color(0xFF1E88E5));
  String _label(String k) => k == 'fakta' ? 'Fakta Unik' : (k == 'tips' ? 'Tips' : 'Info Penting');

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
    final infos = _infos.isEmpty ? _fallback : _infos;
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
                Text('Halo, ${me?.nama ?? ''}! 👋',
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
            if (wide) const Padding(padding: EdgeInsets.only(left: 12), child: Text('🍌', style: TextStyle(fontSize: 96))),
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
          ]),
        const SectionTitle('Enam tingkat kematangan', Icons.category_rounded),
        ResponsiveWrap(minWidth: 300, children: [
          for (final k in kelasList)
            AppCard(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: alpha(k.warna, .2), shape: BoxShape.circle, border: Border.all(color: k.warna, width: 2.5)),
                  child: const Text('🍌', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(k.nama, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kBrown)),
                    const SizedBox(height: 4),
                    Text(k.deskripsi, style: TextStyle(color: Colors.brown.shade400, fontSize: 13, height: 1.35)),
                  ]),
                ),
              ]),
            ),
        ]),
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
        const SectionTitle('Fakta unik & info penting', Icons.auto_awesome_rounded),
        ResponsiveWrap(minWidth: 320, children: [
          for (final i in infos)
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: alpha(_color('${i['kategori']}'), .14), borderRadius: BorderRadius.circular(12)),
                    child: Icon(_icon('${i['kategori']}'), color: _color('${i['kategori']}'), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(_label('${i['kategori']}'),
                      style: TextStyle(fontWeight: FontWeight.w700, color: _color('${i['kategori']}'), fontSize: 13)),
                ]),
                const SizedBox(height: 12),
                Text('${i['judul']}', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: kBrown)),
                const SizedBox(height: 6),
                Text('${i['isi']}', style: TextStyle(color: Colors.brown.shade400, height: 1.45)),
              ]),
            ),
        ]),
      ],
    );
  }
}
