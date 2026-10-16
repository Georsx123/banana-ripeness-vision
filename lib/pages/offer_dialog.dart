import 'package:flutter/material.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets.dart';

/// Jendela penawaran paket (hanya tampilan, tanpa tombol pilih). Muncul setiap login untuk user biasa.
Future<void> showOfferDialog(BuildContext context, String currentPlan) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Stack(children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.only(right: 34),
                child: Text('Paket scan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kBrown)),
              ),
              const SizedBox(height: 4),
              Text('Batas scan per hari di ${AppConfig.appName} sesuai tipe akunmu.',
                  style: TextStyle(color: Colors.brown.shade500, height: 1.35)),
              const SizedBox(height: 16),
              for (final p in planList)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: alpha(p.warna, .08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: alpha(p.warna, p.key == currentPlan ? 1 : .35), width: p.key == currentPlan ? 2.5 : 1),
                  ),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: alpha(p.warna, .18), shape: BoxShape.circle),
                      child: Icon(p.ikon, color: p.warna),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          Text(p.nama, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: kBrown)),
                          if (p.key == currentPlan)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: p.warna, borderRadius: BorderRadius.circular(20)),
                              child: const Text('Paketmu', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                            ),
                        ]),
                        const SizedBox(height: 2),
                        Text('${p.limit} scan per hari', style: const TextStyle(fontWeight: FontWeight.w700, color: kBrown)),
                        Text(p.harga == 'Gratis' ? 'Gratis' : 'Berbayar \u2022 harga segera diumumkan',
                            style: TextStyle(color: Colors.brown.shade400, fontSize: 12.5)),
                      ]),
                    ),
                  ]),
                ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: alpha(kAmber, .15), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  'Pembelian paket segera hadir. Untuk saat ini perubahan paket dilakukan oleh admin. Kontak admin ada di menu About.',
                  style: TextStyle(color: Colors.brown.shade700, fontSize: 12.5, height: 1.35),
                ),
              ),
            ]),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: IconButton(tooltip: 'Tutup', icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
          ),
        ]),
      ),
    ),
  );
}
