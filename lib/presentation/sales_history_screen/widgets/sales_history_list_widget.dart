import '../../../core/app_export.dart';

class SalesHistoryListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> sales;

  const SalesHistoryListWidget({super.key, required this.sales});

  // Group sales by date
  Map<String, List<Map<String, dynamic>>> get _grouped {
    final Map<String, List<Map<String, dynamic>>> result = {};
    for (final sale in sales) {
      final date = sale['date'] as String;
      result.putIfAbsent(date, () => []).add(sale);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final dates = grouped.keys.toList();

    final List<Widget> items = [];
    for (final date in dates) {
      // Section header
      final dayTotal = grouped[date]!.fold(
        0.0,
        (sum, s) => sum + (s['total'] as double),
      );

      items.add(
        SliverToBoxAdapter(
          key: Key('header-$date'),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    date,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'S/ ${dayTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      for (final sale in grouped[date]!) {
        items.add(
          SliverToBoxAdapter(
            key: Key('sale-${sale['id']}'),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SaleItem(sale: sale),
            ),
          ),
        );
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (sales.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'No hay ventas en este período.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
          );
        }

        // Flatten grouped structure
        final grouped2 = _grouped;
        final dates2 = grouped2.keys.toList();
        int counter = 0;
        for (final d in dates2) {
          if (index == counter) {
            // Header
            final dayTotal2 = grouped2[d]!.fold(
              0.0,
              (sum, s) => sum + (s['total'] as double),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      d,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'S/ ${dayTotal2.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          }
          counter++;
          final groupSales = grouped2[d]!;
          for (final sale in groupSales) {
            if (index == counter) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SaleItem(sale: sale),
              );
            }
            counter++;
          }
        }
        return null;
      }, childCount: sales.length + _grouped.keys.length),
    );
  }
}

class _SaleItem extends StatelessWidget {
  final Map<String, dynamic> sale;

  const _SaleItem({required this.sale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CustomImageWidget(
              imageUrl: sale['imageUrl'] as String,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              semanticLabel: sale['semanticLabel'] as String,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale['productName'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sale['category'] as String,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${sale['quantity']} und.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  sale['time'] as String,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'S/ ${(sale['total'] as double).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryDark,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'S/ ${(sale['unitPrice'] as double).toStringAsFixed(2)}/und.',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
