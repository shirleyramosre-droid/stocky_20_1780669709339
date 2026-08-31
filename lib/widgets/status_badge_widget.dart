import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum StockStatus { available, lowStock, outOfStock, active }

class StatusBadgeWidget extends StatelessWidget {
  final StockStatus status;
  final String? customLabel;

  const StatusBadgeWidget({super.key, required this.status, this.customLabel});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case StockStatus.available:
        bg = AppTheme.primaryContainer;
        text = AppTheme.primaryDark;
        label = customLabel ?? 'Disponible';
        break;
      case StockStatus.lowStock:
        bg = AppTheme.warningLight;
        text = AppTheme.warning;
        label = customLabel ?? 'Stock Bajo';
        break;
      case StockStatus.outOfStock:
        bg = AppTheme.cancelRedLight;
        text = AppTheme.cancelRed;
        label = customLabel ?? 'Agotado';
        break;
      case StockStatus.active:
        bg = AppTheme.primaryContainer;
        text = AppTheme.primaryDark;
        label = customLabel ?? 'Activo';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
