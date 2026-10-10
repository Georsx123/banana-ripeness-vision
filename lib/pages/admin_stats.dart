import 'package:flutter/material.dart';
import '../charts.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class AdminStatsPage extends StatefulWidget {
  const AdminStatsPage({super.key});
  @override
  State<AdminStatsPage> createState() => _AdminStatsPageState();
}

class _AdminStatsPageState extends State<AdminStatsPage> {
  Map<String, dynamic>? _s;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _s = await Api.adminStats();
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return PageWrap(
      title: 'Statistik',
      subtitle: 'Ringkasan seluruh aktivitas aplikasi.',
      trailing: IconButton.filledTonal(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Muat ulang'),
      children: [
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (s == null)
          const AppCard(child: Text('Data statistik tidak tersedia. Pastikan skrip SQL sudah dijalankan.'))
        else ...[
          ResponsiveWrap(minWidth: 230, children: [
            StatCard(icon: Icons.people_rounded, label: 'Total pengguna', value: '${s['total_user']}', color: kDeepAmber),
            StatCard(icon: Icons.admin_panel_settings_rounded, label: 'Admin', value: '${s['total_admin']}', color: const Color(0xFF8E24AA)),
            StatCard(icon: Icons.qr_code_scanner_rounded, label: 'Total scan', value: '${s['total_scan']}', color: kGreen),
            StatCard(icon: Icons.today_rounded, label: 'Scan hari ini', value: '${s['scan_hari_ini']}', color: const Color(0xFF1E88E5)),
          ]),
          const SizedBox(height: 16),
          ResponsiveWrap(minWidth: 420, children: [
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Pisang terdeteksi per kelas (semua pengguna)', style: TextStyle(fontWeight: FontWeight.w800, color: kBrown)),
                const SizedBox(height: 14),
                ClassBarChart(counts: {
                  for (final e in Map<String, dynamic>.from(s['per_kelas'] as Map).entries) infoKelas(e.key).key: (e.value as num).toInt()
                }),
              ]),
            ),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Aktivitas scan 7 hari terakhir', style: TextStyle(fontWeight: FontWeight.w800, color: kBrown)),
                const SizedBox(height: 14),
                Builder(builder: (_) {
                  final list = List<Map<String, dynamic>>.from((s['per_hari'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
                  return SimpleBarChart(
                    labels: [for (final e in list) '${e['label']}'],
                    values: [for (final e in list) (e['jumlah'] as num).toDouble()],
                    colors: const [kDeepAmber],
                  );
                }),
              ]),
            ),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Proporsi hasil scan', style: TextStyle(fontWeight: FontWeight.w800, color: kBrown)),
                const SizedBox(height: 14),
                ClassPieChart(counts: {
                  for (final e in Map<String, dynamic>.from(s['per_kelas'] as Map).entries) infoKelas(e.key).key: (e.value as num).toInt()
                }),
              ]),
            ),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Pengguna berdasarkan jenis kelamin', style: TextStyle(fontWeight: FontWeight.w800, color: kBrown)),
                const SizedBox(height: 14),
                Builder(builder: (_) {
                  final g = Map<String, dynamic>.from(s['per_gender'] as Map);
                  final keys = g.keys.toList();
                  return SimpleBarChart(
                    labels: keys,
                    values: [for (final k in keys) (g[k] as num).toDouble()],
                    colors: const [Color(0xFF1E88E5), Color(0xFFE91E63), Colors.grey],
                  );
                }),
              ]),
            ),
          ]),
        ],
      ],
    );
  }
}
