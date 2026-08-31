import 'dart:convert';
import 'dart:io' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/app_theme.dart';
import '../../../services/supabase_service.dart';
import '../../../services/garment_vision_service.dart';
import '../../../services/sync_service.dart';

class NewProductFormWidget extends StatefulWidget {
  final dynamic capturedImageFile;

  const NewProductFormWidget({super.key, this.capturedImageFile});

  @override
  State<NewProductFormWidget> createState() => _NewProductFormWidgetState();
}

class _NewProductFormWidgetState extends State<NewProductFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  late TextEditingController _quantityController;
  int _quantity = 1;
  String? _selectedCategory;
  String? _selectedSize;
  bool _isSaving = false;
  bool _isLoadingCategories = true;

  // AI tags state
  String? _aiTags;
  bool _isAnalyzingTags = false;
  String? _aiTagsError;

  List<String> _categories = [];

  static const List<String> _defaultSizes = ['S', 'M', 'L'];
  final List<String> _sizes = ['S', 'M', 'L'];

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
    _loadCategories();
    // Trigger AI analysis if image was already provided at creation time
    if (widget.capturedImageFile != null) {
      _analyzeImageForTags();
    }
  }

  @override
  void didUpdateWidget(covariant NewProductFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger AI analysis when a new image is provided
    if (widget.capturedImageFile != null &&
        widget.capturedImageFile != oldWidget.capturedImageFile) {
      _analyzeImageForTags();
    }
  }

  Future<void> _loadCategories() async {
    final cats = await SupabaseService.instance.getCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        _isLoadingCategories = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _incrementQuantity() {
    setState(() {
      _quantity++;
      _quantityController.text = '$_quantity';
    });
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
        _quantityController.text = '$_quantity';
      });
    }
  }

  void _onQuantityTyped(String val) {
    final parsed = int.tryParse(val);
    if (parsed != null && parsed >= 1) setState(() => _quantity = parsed);
  }

  Future<void> _onCancel() async {
    final hasData =
        _nameController.text.isNotEmpty ||
        _priceController.text.isNotEmpty ||
        widget.capturedImageFile != null;

    if (!hasData) {
      Navigator.pop(context);
      return;
    }

    final confirm = await _showConfirmDialog(
      context,
      '¿Seguro que desea salir?\nSi lo hace perderá todo su progreso',
    );
    if (confirm == true && mounted) {
      Navigator.pop(context);
    }
  }

  /// Uploads the captured image to Supabase Storage using the centralized service.
  /// Returns the public URL or null on failure.
  Future<String?> _uploadImage() async {
    if (widget.capturedImageFile == null) return null;
    try {
      Uint8List? bytes;

      if (kIsWeb && widget.capturedImageFile is String) {
        final String dataUrl = widget.capturedImageFile as String;
        final String base64Data = dataUrl.contains(',')
            ? dataUrl.split(',').last
            : dataUrl;
        bytes = base64Decode(base64Data);
      } else if (!kIsWeb && widget.capturedImageFile is XFile) {
        final xFile = widget.capturedImageFile as XFile;
        bytes = await xFile.readAsBytes();
      } else if (!kIsWeb && widget.capturedImageFile is File) {
        bytes = await (widget.capturedImageFile as File).readAsBytes();
      }

      if (bytes == null || bytes.isEmpty) return null;

      // Use centralized upload method that organises by device_id
      final publicUrl = await SupabaseService.instance.uploadProductImage(
        bytes,
      );
      if (publicUrl == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar la foto. El producto se guardará sin imagen.',
            ),
            backgroundColor: AppTheme.cancelRed,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return publicUrl;
    } catch (e) {
      debugPrint('[NewProductForm] image upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo guardar la foto. El producto se guardará sin imagen. Error: $e',
            ),
            backgroundColor: AppTheme.cancelRed,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione una categoría'),
          backgroundColor: AppTheme.cancelRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final totalPrice = double.tryParse(_priceController.text.trim()) ?? 0;
    // Unit price = total price / quantity
    final unitPrice = _quantity > 0 ? totalPrice / _quantity : totalPrice;

    // Step 1: Read image bytes once (reused for upload and AI tagging)
    Uint8List? imageBytes;
    if (widget.capturedImageFile != null) {
      try {
        if (kIsWeb && widget.capturedImageFile is String) {
          final String dataUrl = widget.capturedImageFile as String;
          final String base64Data = dataUrl.contains(',')
              ? dataUrl.split(',').last
              : dataUrl;
          imageBytes = base64Decode(base64Data);
        } else if (!kIsWeb && widget.capturedImageFile is XFile) {
          imageBytes = await (widget.capturedImageFile as XFile).readAsBytes();
        } else if (!kIsWeb && widget.capturedImageFile is File) {
          imageBytes = await (widget.capturedImageFile as File).readAsBytes();
        }
      } catch (e) {
        debugPrint('[NewProductForm] image bytes read error: $e');
      }
    }

    // Step 2: Upload image to Supabase Storage
    String? imageUrl;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      try {
        imageUrl = await SupabaseService.instance.uploadProductImage(
          imageBytes,
        );
        if (imageUrl == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo guardar la foto. El producto se guardará sin imagen.',
              ),
              backgroundColor: AppTheme.cancelRed,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        debugPrint('[NewProductForm] image upload error: $e');
      }
    }

    // Step 3: Insert the product WITHOUT ai_tags first (guarantees the row exists)
    final productName = _nameController.text.trim();
    debugPrint('[AI_TAGS] Producto iniciado: $productName');

    if (imageBytes != null && imageBytes.isNotEmpty) {
      debugPrint('[AI_TAGS] Imagen seleccionada (${imageBytes.length} bytes)');
    } else {
      debugPrint('[AI_TAGS] Sin imagen — ai_tags no se generarán');
    }

    final remoteId = await SupabaseService.instance.insertProductAndGetId(
      name: productName,
      category: _selectedCategory!,
      size: _selectedSize,
      purchasePrice: unitPrice,
      stock: _quantity,
      imageUrl: imageUrl,
    );

    if (remoteId == null) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar. Intente nuevamente.'),
            backgroundColor: AppTheme.cancelRed,
          ),
        );
      }
      return;
    }

    debugPrint('[AI_TAGS] Producto guardado con id: $remoteId');
    if (imageUrl != null) {
      debugPrint('[AI_TAGS] Image URL: $imageUrl');
    }

    // Step 4: Use already-generated ai_tags (from automatic analysis on photo capture),
    // or call Gemini now if tags weren't generated yet (e.g. still loading or failed).
    final isOnline = await SyncService.instance.isOnline();
    if (imageBytes != null && imageBytes.isNotEmpty && isOnline) {
      bool geminiError = false;
      String? aiTags;

      // Reuse pre-generated tags if available; otherwise call Gemini now
      if (_aiTags != null && _aiTags!.isNotEmpty) {
        aiTags = _aiTags;
        debugPrint('[AI_TAGS] Usando tags pre-generados: $aiTags');
      } else {
        try {
          debugPrint('[AI_TAGS] Enviando imagen a Gemini...');
          aiTags = await GarmentVisionService.instance.extractTagsFromImage(
            imageBytes,
          );
          debugPrint('[AI_TAGS] Gemini response recibida');
          debugPrint('[AI_TAGS] Tags generados: $aiTags');
        } catch (e) {
          debugPrint('[AI_TAGS] ERROR en extracción de ai_tags: $e');
          geminiError = true;
        }
      }

      if (!geminiError && aiTags != null && aiTags.isNotEmpty) {
        debugPrint(
          '[AI_TAGS] Guardando ai_tags en Supabase para id: $remoteId',
        );
        final updated = await SupabaseService.instance
            .updateProductAiTagsRemote(remoteId, aiTags);
        if (updated) {
          debugPrint('[AI_TAGS] ai_tags final: $aiTags');
          await SupabaseService.instance.refreshProductsAndCategories();
          debugPrint('[AI_TAGS] Producto guardado con ai_tags correctamente');
        } else {
          debugPrint(
            '[AI_TAGS] ERROR - updateProductAiTagsRemote devolvió false',
          );
          geminiError = true;
        }
      } else if (!geminiError) {
        debugPrint('[AI_TAGS] ERROR - Gemini no devolvió tags válidos');
        geminiError = true;
      }

      if (geminiError && mounted) {
        setState(() => _isSaving = false);
        await _showGeminiErrorDialog(context);
        if (mounted) _showSuccessDialog(context);
        return;
      }
    } else if (!isOnline) {
      debugPrint(
        '[AI_TAGS] Sin conexión — ai_tags se generarán cuando haya conexión',
      );
    }

    if (mounted) {
      setState(() => _isSaving = false);
      _showSuccessDialog(context);
    }
  }

  Future<void> _showGeminiErrorDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFE53935),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Análisis de IA no disponible',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'El análisis automático de la prenda con Gemini falló. '
                'El producto fue guardado correctamente, pero sin etiquetas de IA (ai_tags).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(BuildContext context, String message) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.help_rounded,
                  color: Color(0xFFF9A825),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cancelRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'SÍ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'NO',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.success,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Se han registrado las prendas nuevas en el inventario',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'ACEPTAR',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Nueva Categoría',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre de la categoría',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.cancelRed),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty && !_categories.contains(name)) {
                await SupabaseService.instance.addCategory(name);
                if (mounted) {
                  setState(() {
                    _categories.add(name);
                    _selectedCategory = name;
                  });
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _showAddSizeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Nueva Talla',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Ej: XL, XXL, 32, etc.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.cancelRed),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim().toUpperCase();
              if (name.isNotEmpty && !_sizes.contains(name)) {
                setState(() {
                  _sizes.add(name);
                  _selectedSize = name;
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  /// Reads image bytes from the captured file and sends them to Gemini for tag extraction.
  Future<void> _analyzeImageForTags() async {
    if (widget.capturedImageFile == null) return;
    setState(() {
      _isAnalyzingTags = true;
      _aiTags = null;
      _aiTagsError = null;
    });

    try {
      Uint8List? imageBytes;
      if (kIsWeb && widget.capturedImageFile is String) {
        final String dataUrl = widget.capturedImageFile as String;
        final String base64Data = dataUrl.contains(',')
            ? dataUrl.split(',').last
            : dataUrl;
        imageBytes = base64Decode(base64Data);
      } else if (!kIsWeb && widget.capturedImageFile is XFile) {
        imageBytes = await (widget.capturedImageFile as XFile).readAsBytes();
      } else if (!kIsWeb && widget.capturedImageFile is File) {
        imageBytes = await (widget.capturedImageFile as File).readAsBytes();
      }

      if (imageBytes == null || imageBytes.isEmpty) {
        if (mounted) {
          setState(() {
            _isAnalyzingTags = false;
            _aiTagsError = 'No se pudo leer la imagen';
          });
        }
        return;
      }

      final tags = await GarmentVisionService.instance.extractTagsFromImage(
        imageBytes,
      );

      if (mounted) {
        setState(() {
          _isAnalyzingTags = false;
          _aiTags = (tags != null && tags.isNotEmpty) ? tags : null;
          _aiTagsError = (tags == null || tags.isEmpty)
              ? 'Gemini no pudo identificar etiquetas'
              : null;
        });
      }
    } catch (e) {
      debugPrint('[AI_TAGS] Error en análisis automático: $e');
      if (mounted) {
        setState(() {
          _isAnalyzingTags = false;
          _aiTagsError = 'Error al analizar la imagen con IA';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Name
          _buildFieldLabel('Nombre del Producto'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Ej: Polo Lacoste'),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Ingrese el nombre del producto'
                : null,
          ),

          const SizedBox(height: 16),

          // Talla
          _buildFieldLabel('Talla'),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSize,
                isExpanded: true,
                hint: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Seleccionar talla',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                borderRadius: BorderRadius.circular(8),
                items: [
                  ..._sizes.map(
                    (size) => DropdownMenuItem(
                      value: size,
                      child: Text(size, style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: '__add_size__',
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_rounded,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Agregar Tallas',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val == '__add_size__') {
                    _showAddSizeDialog();
                  } else {
                    setState(() => _selectedSize = val);
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Category
          _buildFieldLabel('Categoría'),
          const SizedBox(height: 6),
          _isLoadingCategories
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFCCCCCC),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      hint: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Seleccionar categoría',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      borderRadius: BorderRadius.circular(8),
                      items: [
                        ..._categories.map(
                          (cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(
                              cat,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: '__add__',
                          child: Row(
                            children: [
                              Icon(
                                Icons.add_rounded,
                                color: AppTheme.primary,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Agregar Categoría',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == '__add__') {
                          _showAddCategoryDialog();
                        } else {
                          setState(() => _selectedCategory = val);
                        }
                      },
                    ),
                  ),
                ),

          const SizedBox(height: 16),

          // Quantity
          _buildFieldLabel('Cantidad'),
          const SizedBox(height: 6),
          _buildQuantitySelector(),

          const SizedBox(height: 16),

          // Price
          _buildFieldLabel('Precio de Compra Total'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              prefixText: 'S/ ',
              prefixStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              hintText: '0.00',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingrese el precio';
              final val = double.tryParse(v);
              if (val == null || val <= 0) return 'Ingrese un precio válido';
              return null;
            },
          ),

          // AI Tags field — only shown when an image is present
          if (widget.capturedImageFile != null) ...[
            const SizedBox(height: 16),
            _buildAiTagsField(),
          ],

          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onCancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cancelRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                  ),
                  child: const Text(
                    'CANCELAR',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'GUARDAR',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildAiTagsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildFieldLabel('Etiquetas IA'),
            const SizedBox(width: 6),
            if (_isAnalyzingTags)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_aiTags != null)
              const Icon(Icons.auto_awesome, size: 14, color: AppTheme.primary),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: _aiTagsError != null
                  ? AppTheme.cancelRed.withAlpha(128)
                  : const Color(0xFFCCCCCC),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFF8F8F8),
          ),
          child: _isAnalyzingTags
              ? const Text(
                  'Analizando imagen con Gemini…',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : _aiTagsError != null
              ? Text(
                  _aiTagsError!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.cancelRed,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : _aiTags != null
              ? Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _aiTags!
                      .split(';')
                      .map((t) => t.trim())
                      .where((t) => t.isNotEmpty)
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primary.withAlpha(77),
                            ),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                )
              : const Text(
                  'Sin imagen — no se generarán etiquetas',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _QuantityButton(
            icon: Icons.remove_rounded,
            onTap: _decrementQuantity,
            enabled: _quantity > 1,
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 60,
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: _onQuantityTyped,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
          _QuantityButton(
            icon: Icons.add_rounded,
            onTap: _incrementQuantity,
            enabled: true,
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _QuantityButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppTheme.primaryContainer : const Color(0xFFF0F0F0),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 56,
          height: 36,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppTheme.primaryDark : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
