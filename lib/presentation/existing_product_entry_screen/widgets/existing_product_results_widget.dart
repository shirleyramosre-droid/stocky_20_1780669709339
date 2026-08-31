import '../../../core/app_export.dart';

class ExistingProductResultsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final ValueChanged<Map<String, dynamic>> onProductSelected;

  const ExistingProductResultsWidget({
    super.key,
    required this.products,
    required this.onProductSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'No se encontraron productos.\nIntente con otro nombre.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${products.length} resultado${products.length != 1 ? 's' : ''} encontrado${products.length != 1 ? 's' : ''}',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final product = products[index];
            final int qty =
                (product['stock'] as int?) ??
                (product['quantity'] as int?) ??
                0;
            final bool isLow = qty <= 1;
            final bool isOut = qty == 0;
            final String imageUrl =
                (product['image_url'] as String?) ??
                (product['imageUrl'] as String?) ??
                '';
            final String? size = product['size'] as String?;

            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                splashColor: AppTheme.primary.withAlpha(26),
                onTap: () => onProductSelected(product),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isOut
                          ? AppTheme.cancelRed.withAlpha(102)
                          : isLow
                          ? AppTheme.warning.withAlpha(102)
                          : const Color(0xFFE0E0E0),
                      width: 1.5,
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
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl.isNotEmpty
                            ? CustomImageWidget(
                                imageUrl: imageUrl,
                                width: 52,
                                height: 52,
                                fit: BoxFit.contain,
                                semanticLabel: 'Imagen de ${product['name']}',
                              )
                            : Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.checkroom_rounded,
                                  color: AppTheme.primary,
                                  size: 26,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (product['name'] as String?) ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Categoría: ${(product['category'] as String?) ?? ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (size != null && size.isNotEmpty)
                              Text(
                                'Talla: $size',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Text(
                                  'Cant: ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  isOut
                                      ? '0 und. disponibles'
                                      : '$qty und. disponibles',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isOut || isLow
                                        ? AppTheme.cancelRed
                                        : AppTheme.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
