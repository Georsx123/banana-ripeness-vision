import 'package:flutter/material.dart';
import '../config.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

/// Menu Plan: hanya tampilan (tanpa tombol pilih). Mengikuti paket yang ditetapkan admin.
class PlanPage extends StatefulWidget {
  const PlanPage({super.key});
  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  @override
  void initState() {
    super.initState();
    Api.refreshQuota();
    // Ambil data terbaru supaya perubahan paket oleh admin langsung terlihat.
    Api.loadProfile().then((_) {
      if (mounted) setState(() {});
    }, onError: (_) {});
  }

  Widget _tile(PlanInfo p, bool current) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: alpha(p.warna, current ? .12 : .06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: alpha(p.warna, current ? 1 : .35), width: current ? 2.5 : 1),
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: alpha(p.warna, .2), shape: BoxShape.circle),
          child: Icon(p.ikon, color: p.warna, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(p.nama, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: kBrown)),
              if (current)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(color: p.warna, borderRadius: BorderRadius.circular(20)),
                  child: const Text('Paketmu', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                ),
            ]),
            const SizedBox(height: 4),
            Text('${p.limit} scan per hari', style: const TextStyle(fontWeight: FontWeight.w800, color: kBrown, fontSize: 15)),
            const SizedBox(height: 2),
            Text(p.harga == 'Gratis' ? 'Gratis' : 'Berbayar \u2022 harga segera diumumkan', style: TextStyle(color: Colors.brown.shade400, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = AppState.me;
    final isAdmin = me?.isAdmin ?? false;
    final current = isAdmin ? '' : (me?.plan ?? 'reguler');
    return PageWrap(
      title: 'Plan',
      subtitle: 'Paket scan dan batas harian akunmu.',
      children: [
        if (isAdmin)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.green.shade300, width: 1.5)),
            child: Row(children: [
              const PlanBadge(plan: 'admin', admin: true),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ini akun admin: scan tanpa batas dan tidak terikat paket. Daftar di bawah menampilkan paket yang berlaku untuk pengguna.',
                  style: TextStyle(color: Colors.green.shade900, height: 1.4, fontSize: 13),
                ),
              ),
            ]),
          ),
        const QuotaBar(),
        const SectionTitle('Daftar paket', Icons.workspace_premium_rounded),
        ResponsiveWrap(minWidth: 300, children: [for (final p in planList) _tile(p, p.key == current)]),
        const SizedBox(height: 14),
        AppCard(
          color: alpha(kAmber, .12),
          child: Text(
            'Pembelian paket segera hadir. Untuk saat ini perubahan paket dilakukan oleh admin. '
            'Kontak admin: ${AppConfig.contactWa} \u2022 ${AppConfig.contactEmail}',
            style: TextStyle(color: Colors.brown.shade700, height: 1.4, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
