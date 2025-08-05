import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class BpmChart extends StatelessWidget {
  final List<int> bpmData;
  final bool isRealTime;

  const BpmChart({super.key, required this.bpmData, this.isRealTime = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(show: true),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: _generateSpots(),
              isCurved: true,
              color: Colors.red,
              barWidth: 2,
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _generateSpots() {
    return bpmData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.toDouble());
    }).toList();
  }
}
