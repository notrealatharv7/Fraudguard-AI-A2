import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fraud_detector/models/transaction_input.dart';
import 'dart:math';

class TransactionDeviationStockChart extends StatefulWidget {
  final List<TransactionInput> transactions;
  final bool isDarkTheme;

  const TransactionDeviationStockChart({
    Key? key,
    required this.transactions,
    this.isDarkTheme = true,
  }) : super(key: key);

  @override
  State<TransactionDeviationStockChart> createState() => _TransactionDeviationStockChartState();
}

class _TransactionDeviationStockChartState extends State<TransactionDeviationStockChart> {
  // Crosshair index to sync hover across charts
  int? touchedIndex;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkTheme ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkTheme ? Colors.white70 : Colors.black87;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Composite Deviation Index (Main Panel)
          _buildPanel(
            title: "Composite Deviation Index",
            parameters: widget.transactions.map((t) => _calculateCompositeScore(t)).toList(),
            height: 120,
            isMain: true,
            color: Colors.cyanAccent,
          ),
          const SizedBox(height: 4),
          // 2. Transaction Amount Deviation
          _buildPanel(
            title: "Amount Deviation",
            parameters: widget.transactions.map((t) => t.transactionAmountDeviation).toList(),
            color: Colors.blue,
          ),
          const SizedBox(height: 2),
           // 3. Time Anomaly
          _buildPanel(
            title: "Time Anomaly",
            parameters: widget.transactions.map((t) => t.timeAnomaly).toList(),
            color: Colors.purple,
          ),
          const SizedBox(height: 2),
           // 4. Location Distance
          _buildPanel(
            title: "Location Distance",
            parameters: widget.transactions.map((t) => t.locationDistance).toList(),
            color: Colors.orange,
          ),
          const SizedBox(height: 2),
           // 5. Merchant Novelty
          _buildPanel(
            title: "Merchant Novelty",
            parameters: widget.transactions.map((t) => t.merchantNovelty).toList(),
            color: Colors.pink,
          ),
           const SizedBox(height: 2),
           // 6. Device/Freq Anomaly
          _buildPanel(
            title: "Frequency Anomaly",
            parameters: widget.transactions.map((t) => t.transactionFrequency).toList(),
            color: Colors.teal,
          ),
          const SizedBox(height: 2),
          // 7. Fraud Risk Score (Simulated or Real)
          _buildPanel(
            title: "Fraud Risk Score",
            parameters: widget.transactions.map((t) => _calculateRiskScore(t)).toList(), // Mock if not in model
            color: Colors.redAccent,
            showThresholds: true,
          ),
        ],
      ),
    );
  }

  double _calculateCompositeScore(TransactionInput t) {
     // Weighted sum
     return (t.transactionAmountDeviation * 0.3) + 
            (t.timeAnomaly * 0.2) + 
            (t.merchantNovelty * 0.2) + 
            (t.locationDistance > 0 ? 0.2 : 0) +
            (t.transactionFrequency > 10 ? 0.3: 0);
  }

  double _calculateRiskScore(TransactionInput t) {
      // Simple heuristic for visualization if model score isn't explicitly passed
      double score = _calculateCompositeScore(t);
      return min(score, 1.0);
  }


  Widget _buildPanel({
    required String title,
    required List<double> parameters,
    double height = 60,
    bool isMain = false,
    required Color color,
    bool showThresholds = false,
  }) {
    // Generate spots
    List<FlSpot> spots = [];
    for (int i = 0; i < parameters.length; i++) {
        spots.add(FlSpot(i.doubleValue, parameters[i]));
    }
    
    // Determine min/max for scaling
    double maxY = 1.0;
    if (parameters.isNotEmpty) {
        maxY = parameters.reduce(max);
        if (maxY < 1.0) maxY = 1.0;
        maxY = maxY * 1.2; // buffer
    }


    return SizedBox(
      height: height,
      child: Row(
        children: [
          // Y-Axis Label Area (Trading style)
          SizedBox(
            width: 50,
            child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                    Text(title, style: TextStyle(color: Colors.grey, fontSize: 8), overflow: TextOverflow.ellipsis),
                    Text(maxY.toStringAsFixed(1), style: TextStyle(color: Colors.white30, fontSize: 8)),
                    const Text("0.0", style: TextStyle(color: Colors.white30, fontSize: 8)),
                ],
            ),
          ),
          // Chart
          Expanded(
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                    enabled: true,
                    touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                         if (response != null && response.lineBarSpots != null && event is! FlTapUpEvent) {
                             setState(() {
                                 touchedIndex = response.lineBarSpots!.first.spotIndex;
                             });
                         } else {
                            // Don't modify touchedIndex on exit to keep last value or handle complex logic
                         }
                    },
                    getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                        return spotIndexes.map((spotIndex) {
                            return TouchedSpotIndicatorData(
                                FlLine(color: Colors.white30, strokeWidth: 1), // Crosshair
                                FlDotData(show: true),
                            );
                        }).toList();
                    },
                     touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: Colors.black87,
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                             return touchedBarSpots.map((barSpot) {
                                 final val = barSpot.y;
                                 return LineTooltipItem(
                                     "${val.toStringAsFixed(2)}",
                                     TextStyle(color: color, fontWeight: FontWeight.bold),
                                 );
                             }).toList();
                        }
                    ),
                ),
                gridData: FlGridData(
                    show: true, 
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: max((parameters.length - 1).toDouble(), 10.0),
                minY: 0,
                maxY: maxY,
                showingTooltipIndicators: touchedIndex != null && touchedIndex! < parameters.length 
                    ? [ShowingTooltipIndicators([LineBarSpot(
                        LineChartBarData(spots: spots),
                        touchedIndex!,
                        spots[touchedIndex!],
                      )])]
                    : [],
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: isMain ? 2 : 1.5,
                    color: color,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                        show: isMain, 
                        color: color.withOpacity(0.1)
                    ),
                  ),
                ],
                // Add Red zones
                extraLinesData: showThresholds ? ExtraLinesData(
                    horizontalLines: [
                        HorizontalLine(y: 0.7, color: Colors.red.withOpacity(0.5), strokeWidth: 1, dashArray: [5, 5]),
                    ]
                ) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension IntDouble on int {
    double get doubleValue => this.toDouble();
}
