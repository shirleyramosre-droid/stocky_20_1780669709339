import '../../../core/app_export.dart';

class ProductCatalogListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> products;

  const ProductCatalogListWidget({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final p = products[index];
        final int qty = p['quantity'] as int;
        final bool isOut = qty == 0;
        final bool isLow = qty <= 1 && qty > 0;

        return Dismissible(
          key: Key('catalog-${p['id']}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppTheme.cancelRed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('¿Eliminar prenda?'),
                content: Text('¿Seguro que desea eliminar "${p['name']}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cancelRed,
                    ),
                    child: const Text(
                      'Eliminar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(
                      color: isOut
                          ? AppTheme.cancelRed
                          : isLow
                          ? AppTheme.warning
                          : AppTheme.primary,
                      width: 4,
                    ),
                    top: BorderSide(color: const Color(0xFFE8E8E8), width: 1),
                    right: BorderSide(color: const Color(0xFFE8E8E8), width: 1),
                    bottom: BorderSide(
                      color: const Color(0xFFE8E8E8),
                      width: 1,
                    ),
                  ),
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
                        imageUrl: p['imageUrl'] as String,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        semanticLabel: p['semanticLabel'] as String,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
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
                                  p['category'] as String,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.primaryDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if ((p['size'] as String?)?.isNotEmpty ==
                                  true) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E5F5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'T: ${p['size']}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF7B1FA2),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Text(
                                isOut ? 'Agotado' : '$qty und. disponibles',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isOut || isLow
                                      ? AppTheme.cancelRed
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'S/ ${(p['price'] as double).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryDark,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.textMuted,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
