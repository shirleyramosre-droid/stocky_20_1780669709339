import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_image_widget.dart';

class SalesHistoryTopProductsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> topVendidas;
  final List<Map<String, dynamic>> topGanancia;

  const SalesHistoryTopProductsWidget({
    super.key,
    required this.topVendidas,
    required this.topGanancia,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopSection(
          title: 'Prendas Más Vendidas',
          items: topVendidas,
          metricIcon: Icons.bar_chart_rounded,
          metricColor: const Color(0xFF1E6FBF),
          metricBgColor: const Color(0xFFE3F0FB),
          metricBuilder: (item) => '${item['qty']} unidades vendidas',
        ),
        const SizedBox(height: 16),
        _buildTopSection(
          title: 'Prendas con Mayor Ganancia Diaria',
          items: topGanancia,
          metricIcon: Icons.monetization_on_outlined,
          metricColor: const Color(0xFF2E7D32),
          metricBgColor: const Color(0xFFE8F5E9),
          metricBuilder: (item) =>
              'Ganancia: S/ ${(item['ganancia'] as double).toStringAsFixed(2)}',
        ),
      ],
    );
  }

  Widget _buildTopSection({
    required String title,
    required List<Map<String, dynamic>> items,
    required IconData metricIcon,
    required Color metricColor,
    required Color metricBgColor,
    required String Function(Map<String, dynamic>) metricBuilder,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Sin datos para este día',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final item = entry.value;
              final name = (item['name'] as String?) ?? '';
              final imageUrl =
                  (item['image_url'] as String?) ?? _getFallbackImage(name);
              return Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key < items.length - 1 ? 10 : 0,
                ),
                child: Row(
                  children: [
                    // Rank badge
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: rank == 1
                            ? const Color(0xFFFFD700)
                            : rank == 2
                            ? const Color(0xFFC0C0C0)
                            : const Color(0xFFCD7F32),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Product image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CustomImageWidget(
                        imageUrl: imageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.contain,
                        semanticLabel: 'Imagen de $name',
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name + metric
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: metricBgColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(metricIcon, size: 12, color: metricColor),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    metricBuilder(item),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: metricColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _getFallbackImage(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('polo') ||
        lower.contains('lacoste') ||
        lower.contains('tommy')) {
      return 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=80&q=70';
    } else if (lower.contains('jean') || lower.contains('short jean')) {
      return 'https://images.unsplash.com/photo-1542272604-787c3835535d?w=80&q=70';
    } else if (lower.contains('casaca') || lower.contains('adidas')) {
      return 'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=80&q=70';
    } else if (lower.contains('vestido')) {
      return 'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=80&q=70';
    } else if (lower.contains('blusa')) {
      return 'https://images.unsplash.com/photo-1564257631407-4deb1f99d992?w=80&q=70';
    }
    return 'https://images.pexels.com/photos/996329/pexels-photo-996329.jpeg?w=80&q=70';
  }
}
