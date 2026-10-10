import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'theme.dart';
import 'widgets.dart';

AxisTitles _noTitles() => AxisTitles(sideTitles: SideTitles(showTitles: false));

class LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  const LegendItem(this.color, this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 12, color: kBrown)),
    ]);
  }
}

class SimpleBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final List<Color> colors;
  final double height;
  const SimpleBarChart({super.key, required this.labels, required this.values, required this.colors, this.height = 230});

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 1.0 : math.max(1.0, values.reduce(math.max));
    final interval = math.max(1.0, (maxV / 4).ceilToDouble());
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          minY: 0,
          maxY: (maxV * 1.2).ceilToDouble(),
          gridData: FlGridData(drawVerticalLine: false, horizontalInterval: interval),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: _noTitles(),
            rightTitles: _noTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: interval,
                getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: kBrown)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                getTitlesWidget: (v, m) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(labels[i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kBrown)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: colors[i % colors.length],
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

class ClassBarChart extends StatelessWidget {
  final Map<String, int> counts;
  const ClassBarChart({super.key, required this.counts});
  @override
  Widget build(BuildContext context) {
    return SimpleBarChart(
      labels: [for (final k in kelasList) k.short],
      values: [for (final k in kelasList) (counts[k.key] ?? 0).toDouble()],
      colors: [for (final k in kelasList) k.warna],
    );
  }
}

class ClassPieChart extends StatelessWidget {
  final Map<String, int> counts;
  const ClassPieChart({super.key, required this.counts});
  @override
  Widget build(BuildContext context) {
    final items = kelasList.where((k) => (counts[k.key] ?? 0) > 0).toList();
    if (items.isEmpty) return const SizedBox(height: 150, child: Center(child: Text('Belum ada data')));
    return Column(children: [
      SizedBox(
        height: 190,
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 34,
          sections: [
            for (final k in items)
              PieChartSectionData(
                value: counts[k.key]!.toDouble(),
                color: k.warna,
                radius: 56,
                title: '${counts[k.key]}',
                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
          ],
        )),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 6, children: [for (final k in items) LegendItem(k.warna, k.nama)]),
    ]);
  }
}

/// Grafik edukasi: perubahan pati dan gula saat pisang matang.
class StageLineChart extends StatelessWidget {
  const StageLineChart({super.key});
  @override
  Widget build(BuildContext context) {
    const pati = <double>[95, 85, 60, 35, 15, 5, 2];
    const gula = <double>[2, 8, 20, 40, 70, 85, 90];
    LineChartBarData line(List<double> d, Color c) => LineChartBarData(
          spots: [for (var i = 0; i < d.length; i++) FlSpot(i + 1.0, d[i])],
          isCurved: true,
          color: c,
          barWidth: 4,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: alpha(c, .12)),
        );
    return Column(children: [
      SizedBox(
        height: 210,
        child: LineChart(LineChartData(
          minX: 1,
          maxX: 7,
          minY: 0,
          maxY: 100,
          gridData: FlGridData(drawVerticalLine: false, horizontalInterval: 25),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: _noTitles(),
            rightTitles: _noTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 25,
                getTitlesWidget: (v, m) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10, color: kBrown)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (v, m) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('T${v.toInt()}', style: const TextStyle(fontSize: 10, color: kBrown)),
                ),
              ),
            ),
          ),
          lineBarsData: [line(pati, kGreen), line(gula, kAmber)],
        )),
      ),
      const SizedBox(height: 8),
      const Wrap(spacing: 14, children: [LegendItem(kGreen, 'Pati'), LegendItem(kAmber, 'Gula')]),
      const SizedBox(height: 4),
      Text('T1 = hijau mentah, T7 = berbintik cokelat. Ilustrasi relatif.',
          style: TextStyle(fontSize: 11, color: Colors.brown.shade300)),
    ]);
  }
}

/// Komposisi pisang per 100 gram (perkiraan).
class CompositionPie extends StatelessWidget {
  const CompositionPie({super.key});
  @override
  Widget build(BuildContext context) {
    final data = <(String, double, Color)>[
      ('Air', 74.9, const Color(0xFF42A5F5)),
      ('Karbohidrat', 22.8, kAmber),
      ('Protein', 1.1, kGreen),
      ('Lemak', 0.3, const Color(0xFF8D6E63)),
      ('Lainnya', 0.9, Colors.grey),
    ];
    return Column(children: [
      SizedBox(
        height: 190,
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 34,
          sections: [
            for (final d in data)
              PieChartSectionData(
                value: d.$2,
                color: d.$3,
                radius: 56,
                title: d.$2 > 5 ? '${d.$2.toStringAsFixed(0)}%' : '',
                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
          ],
        )),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 6, children: [for (final d in data) LegendItem(d.$3, '${d.$1} ${d.$2}%')]),
      const SizedBox(height: 4),
      Text('Per 100 gram pisang (perkiraan).', style: TextStyle(fontSize: 11, color: Colors.brown.shade300)),
    ]);
  }
}
