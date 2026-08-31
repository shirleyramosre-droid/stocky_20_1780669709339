import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class SalesHistoryKpiWidget extends StatelessWidget {
  final double totalRevenue;
  final int totalUnits;
  final double dailyProfit;

  const SalesHistoryKpiWidget({
    super.key,
    required this.totalRevenue,
    required this.totalUnits,
    required this.dailyProfit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            icon: Icons.shopping_bag_outlined,
            iconColor: const Color(0xFF1E6FBF),
            iconBgColor: const Color(0xFFE3F0FB),
            label: 'Ventas del día',
            value: 'S/ ${totalRevenue.toStringAsFixed(2)}',
            valueColor: const Color(0xFF1E6FBF),
            subtitle: 'Total vendido',
            bgColor: const Color(0xFFEBF4FD),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFF2E7D32),
            iconBgColor: const Color(0xFFE8F5E9),
            label: 'Productos vendidos',
            value: '$totalUnits',
            valueColor: const Color(0xFF2E7D32),
            subtitle: 'Unidades',
            bgColor: const Color(0xFFEDF7EE),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            icon: Icons.attach_money_rounded,
            iconColor: const Color(0xFF6A1B9A),
            iconBgColor: const Color(0xFFF3E5F5),
            label: 'Ganancia del día',
            value: 'S/ ${dailyProfit.toStringAsFixed(2)}',
            valueColor: const Color(0xFF6A1B9A),
            subtitle: 'Utilidad neta',
            bgColor: const Color(0xFFF8F0FC),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String label;
  final String value;
  final Color valueColor;
  final String subtitle;
  final Color bgColor;

  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.subtitle,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
