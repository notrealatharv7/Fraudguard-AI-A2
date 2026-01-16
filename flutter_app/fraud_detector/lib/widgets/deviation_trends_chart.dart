import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fraud_detector/models/transaction_input.dart';
import 'dart:math';

class DeviationTrendsChart extends StatefulWidget {
  final List<TransactionInput> transactions;
  final bool isDarkTheme;

  const DeviationTrendsChart({
    Key? key,
    required this.transactions,
    this.isDarkTheme = false,
  }) : super(key: key);

  @override
  State<DeviationTrendsChart> createState() => _DeviationTrendsChartState();
}

class _DeviationTrendsChartState extends State<DeviationTrendsChart> {
  // Colors from the image (approximate)
  final Color colGreen = const Color(0xFF66C2A5); // SAE
  final Color colOrange = const Color(0xFFFC8D62); // VSAE
  final Color colBlue = const Color(0xFF8DA0CB);   // GM-VSAE-10
  final Color colPink = const Color(0xFFE78AC3);   // LM-TAD

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) return const SizedBox.shrink();

    final data = widget.transactions;
    // Calculate width: ~80px per group (3 bars of 16px + spacing)
    final double chartWidth = max(MediaQuery.of(context).size.width, data.length * 80.0);

    return Column(
      children: [
        _buildLegend(),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: chartWidth,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final t = data[group.x.toInt()];
                        String metricName = "";
                        String actualValue = "";
                        
                        // Map rod index to metric
                        if (rodIndex == 0) {
                           metricName = "Amount Dev";
                           actualValue = "₹${t.transactionAmount}";
                        } else if (rodIndex == 1) {
                           metricName = "Time Anom";
                           actualValue = "${(t.timeAnomaly * 100).toStringAsFixed(0)}%"; 
                        } else if (rodIndex == 2) {
                           metricName = "Merch Nov";
                           actualValue = "${(t.merchantNovelty * 100).toStringAsFixed(0)}%";
                        }

                        return BarTooltipItem(
                          '$metricName\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(
                              text: actualValue,
                              style: const TextStyle(
                                color: Colors.yellowAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < data.length) {
                             return Padding(
                               padding: const EdgeInsets.only(top: 8),
                               child: Text("Tx ${index + 1}", style: const TextStyle(fontSize: 10)),
                             );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                     show: true, 
                     drawVerticalLine: false,
                     horizontalInterval: 0.2,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: data.asMap().entries.map((e) {
                    final index = e.key;
                    final t = e.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        // 1. Amount Deviation (Orange)
                        BarChartRodData(
                          toY: min(t.transactionAmountDeviation, 1.0),
                          color: colOrange,
                          width: 16, // Increased Width
                          borderRadius: BorderRadius.circular(4),
                        ),
                        // 2. Time Anomaly (Blue)
                        BarChartRodData(
                          toY: t.timeAnomaly,
                          color: colBlue,
                          width: 16, // Increased Width
                          borderRadius: BorderRadius.circular(4),
                        ),
                        // 3. Merchant Novelty (Green)
                        BarChartRodData(
                          toY: t.merchantNovelty,
                          color: colGreen,
                          width: 16, // Increased Width
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
      return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              _legendItem("Amt Dev", colOrange, Icons.bar_chart),
              const SizedBox(width: 16),
              _legendItem("Time Anom", colBlue, Icons.bar_chart),
              const SizedBox(width: 16),
              _legendItem("Merch Nov", colGreen, Icons.bar_chart),
          ],
      );
  }

  Widget _legendItem(String text, Color color, IconData icon) {
      return Row(
          children: [
             Icon(icon, color: color, size: 14),
             const SizedBox(width: 4),
             Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
      );
  }
}
