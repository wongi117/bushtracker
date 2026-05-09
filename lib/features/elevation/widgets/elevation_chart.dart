import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/elevation/services/elevation_service.dart';

class ElevationChart extends StatelessWidget {
  final List<ElevationPoint> elevationData;
  final double maxElevation;
  final double minElevation;
  final double totalDistance;

  const ElevationChart({
    super.key,
    required this.elevationData,
    required this.maxElevation,
    required this.minElevation,
    required this.totalDistance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ELEVATION PROFILE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxElevation - minElevation) / 4,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: AppColors.panelLight,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: totalDistance / 4,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${(value / 1000).toStringAsFixed(0)}km',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (maxElevation - minElevation) / 4,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toStringAsFixed(0)}m',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: AppColors.panelLight),
                ),
                minX: 0,
                maxX: totalDistance,
                minY: minElevation - 10,
                maxY: maxElevation + 10,
                lineBarsData: [
                  LineChartBarData(
                    spots: elevationData
                        .map((point) => FlSpot(point.distance, point.elevation))
                        .toList(),
                    isCurved: true,
                    color: AppColors.primaryOrange,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primaryOrange.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard('MAX', '${maxElevation.toStringAsFixed(0)}m', AppColors.statusGreen),
              _buildStatCard('MIN', '${minElevation.toStringAsFixed(0)}m', AppColors.textSecondary),
              _buildStatCard('GAIN', '${(maxElevation - minElevation).toStringAsFixed(0)}m', AppColors.primaryOrange),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}