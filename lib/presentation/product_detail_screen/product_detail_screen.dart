
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/app_export.dart';
import '../../services/garment_vision_service.dart';
import '../../services/supabase_service.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isRegeneratingTags = false;
  String? _currentAiTags;
  late Map<String, dynamic> _product;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _product =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ??
          {};
      _currentAiTags = _product['ai_tags'] as String?;
      _initialized = true;
    }
  }

  Future<void> _regenerateAiTags() async {
    final imageUrl =
        (_product['image_url'] as String?) ??
        (_product['imageUrl'] as String?) ??
        '';

    if (imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este producto no tiene imagen. Agrega una imagen para generar etiquetas IA.',
          ),
          backgroundColor: Color(0xFFE53935),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isRegeneratingTags = true);
    debugPrint('[AI_TAGS] Regenerar etiquetas IA iniciado');
    debugPrint('[AI_TAGS] Image URL: $imageUrl');

    try {
      // Download image bytes from URL
      Uint8List? imageBytes;
      try {
        debugPrint('[AI_TAGS] Descargando imagen desde URL...');
        final response = await http
            .get(Uri.parse(imageUrl))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
          debugPrint('[AI_TAGS] Imagen descargada: ${imageBytes.length} bytes');
        } else {
          debugPrint(
            '[AI_TAGS] ERROR - HTTP ${response.statusCode} al descargar imagen',
          );
        }
      } catch (e) {
        debugPrint('[AI_TAGS] ERROR descargando imagen: $e');
      }

      if (imageBytes == null || imageBytes.isEmpty) {
        if (mounted) {
          setState(() => _isRegeneratingTags = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo descargar la imagen del producto. Intente nuevamente.',
              ),
              backgroundColor: Color(0xFFE53935),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      debugPrint('[AI_TAGS] Enviando imagen a Gemini...');
      final aiTags = await GarmentVisionService.instance.extractTagsFromImage(
        imageBytes,
      );
      debugPrint('[AI_TAGS] Tags generados: $aiTags');

      if (aiTags == null || aiTags.isEmpty) {
        if (mounted) {
          setState(() => _isRegeneratingTags = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gemini no pudo identificar características en la imagen. Intente con otra foto.',
              ),
              backgroundColor: Color(0xFFE53935),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final productId = _product['id']?.toString() ?? '';
      if (productId.isEmpty) {
        debugPrint('[AI_TAGS] ERROR - productId vacío');
        if (mounted) setState(() => _isRegeneratingTags = false);
        return;
      }

      debugPrint('[AI_TAGS] Guardando ai_tags en Supabase para id: $productId');
      final updated = await SupabaseService.instance.updateProductAiTagsRemote(
        productId,
        aiTags,
      );

      if (updated) {
        debugPrint('[AI_TAGS] ai_tags final: $aiTags');
        await SupabaseService.instance.refreshProductsAndCategories();
        if (mounted) {
          setState(() {
            _currentAiTags = aiTags;
            _isRegeneratingTags = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Etiquetas IA regeneradas correctamente'),
              backgroundColor: Color(0xFF2E7D32),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        debugPrint(
          '[AI_TAGS] ERROR - updateProductAiTagsRemote devolvió false',
        );
        if (mounted) {
          setState(() => _isRegeneratingTags = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Error al guardar las etiquetas. Intente nuevamente.',
              ),
              backgroundColor: Color(0xFFE53935),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[AI_TAGS] ERROR en regenerateAiTags: $e');
      if (mounted) {
        setState(() => _isRegeneratingTags = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al regenerar etiquetas: ${e.toString()}'),
            backgroundColor: const Color(0xFFE53935),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int qty = _product['quantity'] as int? ?? 0;
    final bool isLow = qty <= 5;
    final double purchasePrice = _product['purchasePrice'] as double? ?? 0.0;
    final int soldLast7 = _product['soldLast7Days'] as int? ?? 0;
    final double profitLast7 = _product['profitLast7Days'] as double? ?? 0.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'STOCKY',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(64),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'CATÁLOGO DE PRENDAS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              // Product image
              Center(
                child: Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: CustomImageWidget(
                      imageUrl: _product['imageUrl'] as String? ?? '',
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.contain,
                      semanticLabel:
                          _product['semanticLabel'] as String? ??
                          'Product image',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Nombre del Producto
              _buildFieldLabel('Nombre del Producto'),
              const SizedBox(height: 6),
              _buildFieldValue(_product['name'] as String? ?? ''),
              const SizedBox(height: 14),
              // Categoría
              _buildFieldLabel('Categoría'),
              const SizedBox(height: 6),
              _buildFieldValue(_product['category'] as String? ?? ''),
              const SizedBox(height: 14),
              // Cant. Actual
              _buildFieldLabel('Cant. Actual'),
              const SizedBox(height: 6),
              _buildFieldValueColored(
                '$qty und.',
                isLow ? AppTheme.cancelRed : AppTheme.textPrimary,
              ),
              const SizedBox(height: 14),
              // Precio de Compra Promedio Unitario
              _buildFieldLabel('Precio de Compra Promedio Unitario'),
              const SizedBox(height: 6),
              _buildFieldValue('S/ ${purchasePrice.toStringAsFixed(2)}'),
              const SizedBox(height: 14),
              // Unidades vendidas últimos 7 días
              _buildFieldLabel('Unidades vendidas en los últimos 7 días'),
              const SizedBox(height: 6),
              _buildFieldValue('$soldLast7 und.'),
              const SizedBox(height: 14),
              // Ganancia últimos 7 días
              _buildFieldLabel('Ganancia en los últimos 7 días'),
              const SizedBox(height: 6),
              _buildFieldValue('S/ ${profitLast7.toStringAsFixed(1)}'),
              const SizedBox(height: 14),

              // AI Tags section
              _buildFieldLabel('Etiquetas IA (ai_tags)'),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFCCCCCC),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  (_currentAiTags != null && _currentAiTags!.isNotEmpty)
                      ? _currentAiTags!
                      : 'Sin etiquetas IA generadas',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        (_currentAiTags != null && _currentAiTags!.isNotEmpty)
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Regenerar etiquetas IA button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isRegeneratingTags ? null : _regenerateAiTags,
                  icon: _isRegeneratingTags
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary,
                          ),
                        )
                      : const Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                  label: Text(
                    _isRegeneratingTags
                        ? 'Analizando imagen...'
                        : 'Regenerar etiquetas IA',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildFieldValue(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFieldValueColored(String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
