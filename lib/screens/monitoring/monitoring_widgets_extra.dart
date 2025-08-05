import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dopply_app/models/monitoring.dart';
import 'package:dopply_app/core/theme.dart';

class ConnectionStatusCard extends StatelessWidget {
  final bool isConnected;
  final bool isMonitoring;
  const ConnectionStatusCard({
    super.key,
    required this.isConnected,
    required this.isMonitoring,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isConnected ? Colors.green.shade200 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      color: isConnected ? Colors.green.shade50 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isConnected
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color:
                        isConnected
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text('Status Koneksi', style: AppTheme.heading3),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected
                      ? 'Terhubung ke perangkat Dopply'
                      : 'Tidak terhubung',
                  style: AppTheme.bodyText.copyWith(
                    color:
                        isConnected
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (isMonitoring) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Monitoring aktif',
                      style: AppTheme.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RealTimeChartCard extends StatelessWidget {
  final List<BpmDataPoint> data;
  const RealTimeChartCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(Icons.show_chart, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Menunggu data...',
                style: AppTheme.bodyText.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Grafik akan muncul saat monitoring dimulai',
                style: AppTheme.caption.copyWith(color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text('Grafik Real-time', style: AppTheme.heading3),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${data.length} data points',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: data.length > 30 ? data.length * 10.0 : 300,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            drawHorizontalLine: true,
                            verticalInterval: 5,
                            horizontalInterval: 20,
                            getDrawingVerticalLine: (value) {
                              return FlLine(
                                color: Colors.grey.shade300,
                                strokeWidth: 1,
                              );
                            },
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey.shade300,
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                interval: 20,
                                getTitlesWidget:
                                    (value, meta) => Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8.0,
                                      ),
                                      child: Text(
                                        value.toInt().toString(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                            bottomTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots:
                                  data.asMap().entries.map((entry) {
                                    return FlSpot(
                                      entry.key.toDouble(),
                                      entry.value.bpm.toDouble(),
                                    );
                                  }).toList(),
                              isCurved: true,
                              color: AppTheme.primaryColor,
                              barWidth: 3,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter:
                                    (spot, percent, barData, index) =>
                                        FlDotCirclePainter(
                                          radius: 2,
                                          color: AppTheme.primaryColor,
                                          strokeWidth: 0,
                                        ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: AppTheme.primaryColor.withOpacity(0.1),
                              ),
                            ),
                          ],
                          minY: 100,
                          maxY: 180,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CurrentBpmCard extends StatelessWidget {
  final int currentBpm;
  const CurrentBpmCard({super.key, required this.currentBpm});

  Color _getBpmColor(int bpm) {
    if (bpm < 110 || bpm > 170) return Colors.red;
    if (bpm < 120 || bpm > 160) return Colors.orange;
    return Colors.green;
  }

  String _getBpmStatus(int bpm) {
    if (bpm < 110) return 'Rendah';
    if (bpm > 170) return 'Tinggi';
    if (bpm < 120 || bpm > 160) return 'Perhatian';
    return 'Normal';
  }

  @override
  Widget build(BuildContext context) {
    final bpmColor = _getBpmColor(currentBpm);
    final bpmStatus = _getBpmStatus(currentBpm);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bpmColor.withOpacity(0.1), bpmColor.withOpacity(0.05)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite, color: bpmColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'BPM Saat Ini',
                    style: AppTheme.heading3.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: bpmColor.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '$currentBpm',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: bpmColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'beats per minute',
                style: AppTheme.caption.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: bpmColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  bpmStatus,
                  style: AppTheme.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorDisplayCard extends StatelessWidget {
  final String error;
  final VoidCallback onClose;
  const ErrorDisplayCard({
    super.key,
    required this.error,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade300),
      ),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Terjadi Kesalahan',
                    style: AppTheme.heading3.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.red.shade600),
                  onPressed: onClose,
                  tooltip: 'Tutup pesan error',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.red.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: AppTheme.bodyText.copyWith(
                        color: Colors.red.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
