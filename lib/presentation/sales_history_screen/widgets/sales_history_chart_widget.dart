import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../theme/app_theme.dart';

class SalesHistoryChartWidget extends StatefulWidget {
  final List<Map<String, dynamic>> chartData;

  const SalesHistoryChartWidget({super.key, required this.chartData});

  @override
  State<SalesHistoryChartWidget> createState() =>
      _SalesHistoryChartWidgetState();
}

class _SalesHistoryChartWidgetState extends State<SalesHistoryChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chartData.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxY = widget.chartData
        .map((d) => d['total'] as double)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Ventas por Día',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'S/ por día',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _animation,
            builder: (_, __) => SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxY * 1.25,
                  barTouchData: BarTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (response == null || response.spot == null) {
                          _touchedIndex = -1;
                        } else {
                          _touchedIndex = response.spot!.touchedBarGroupIndex;
                        }
                      });
                    },
                    touchTooltipData: BarTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final data = widget.chartData[groupIndex];
                        return BarTooltipItem(
                          'S/ ${(data['total'] as double).toStringAsFixed(0)}\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(
                              text: data['date'] as String,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= widget.chartData.length) {
                            return const SizedBox.shrink();
                          }
                          final dateStr =
                              widget.chartData[index]['date'] as String;
                          final parts = dateStr.split('/');
                          final shortDate = parts.length >= 2
                              ? '${parts[0]}/${parts[1]}'
                              : dateStr;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              shortDate,
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            'S/${value.toInt()}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.textMuted,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: const Color(0xFFE8E8E8),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(widget.chartData.length, (i) {
                    final total =
                        (widget.chartData[i]['total'] as double) *
                        _animation.value;
                    final isTouched = i == _touchedIndex;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: total,
                          width: 22,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          gradient: LinearGradient(
                            colors: isTouched
                                ? [AppTheme.primaryDark, AppTheme.primaryDark]
                                : [AppTheme.primary, AppTheme.primaryDark],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
