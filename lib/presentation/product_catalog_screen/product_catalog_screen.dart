import 'dart:convert';
import 'dart:io' if (dart.library.io) 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_export.dart';
import '../../services/app_state_notifier.dart';
import '../../services/garment_vision_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_navigation_drawer.dart';
import './widgets/product_catalog_grid_widget.dart';

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({super.key});

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  bool _isLoading = true;

  List<Map<String, dynamic>> _products = [];
  List<String> _categories = ['Todos'];

  // Camera state
  dynamic _capturedImageFile;
  bool _imageIsBase64 = false;
  bool _isCameraLoading = false;
  bool _isRecognizing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
    AppStateNotifier.instance.productsVersion.addListener(_onProductsChanged);
    AppStateNotifier.instance.categoriesVersion.addListener(_onProductsChanged);
  }

  @override
  void dispose() {
    AppStateNotifier.instance.productsVersion.removeListener(
      _onProductsChanged,
    );
    AppStateNotifier.instance.categoriesVersion.removeListener(
      _onProductsChanged,
    );
    super.dispose();
  }

  void _onProductsChanged() {
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final cats = await SupabaseService.instance.getCategories();
    final prods = await SupabaseService.instance.getProducts();
    if (mounted) {
      setState(() {
        _categories = ['Todos', ...cats];
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = 'Todos';
        }
        _products = prods.map((p) => _normalizeProduct(p)).toList();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _normalizeProduct(Map<String, dynamic> p) {
    final imageUrl =
        (p['image_url'] as String?) ?? (p['imageUrl'] as String?) ?? '';
    final stock = (p['stock'] as int?) ?? (p['quantity'] as int?) ?? 0;
    final purchasePrice =
        ((p['purchase_price'] as num?) ?? (p['purchasePrice'] as num?) ?? 0)
            .toDouble();
    return {
      ...p,
      'imageUrl': imageUrl,
      'image_url': imageUrl,
      'quantity': stock,
      'stock': stock,
      'price': purchasePrice,
      'purchasePrice': purchasePrice,
      'semanticLabel': 'Imagen de ${(p['name'] as String?) ?? 'producto'}',
    };
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((p) {
      final matchesCategory =
          _selectedCategory == 'Todos' || p['category'] == _selectedCategory;
      final matchesSearch =
          _searchQuery.isEmpty ||
          ((p['name'] as String?) ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      return matchesCategory && matchesSearch;
    }).toList();
  }

  // ── Camera & AI recognition ──────────────────────────────────────────────

  Future<void> _takePhoto() async {
    setState(() => _isCameraLoading = true);
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo != null && mounted) {
        await _cropAndProcess(photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo acceder a la cámara. Verifique los permisos.',
            ),
            backgroundColor: AppTheme.cancelRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCameraLoading = false);
    }
  }

  Future<void> _cropAndProcess(XFile file) async {
    XFile processedFile = file;
    if (!kIsWeb) {
      try {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: file.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Recortar imagen',
              toolbarColor: AppTheme.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Recortar imagen',
              cancelButtonTitle: 'Cancelar',
              doneButtonTitle: 'Listo',
            ),
          ],
        );
        if (croppedFile != null) {
          processedFile = XFile(croppedFile.path);
        }
      } catch (_) {}
    }
    final bytes = await processedFile.readAsBytes();
    final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    if (mounted) {
      setState(() {
        _capturedImageFile = base64Str;
        _imageIsBase64 = true;
      });
      await _recognizeProductFromImage(bytes);
    }
  }

  Future<void> _recognizeProductFromImage(Uint8List imageBytes) async {
    if (!mounted) return;
    setState(() => _isRecognizing = true);

    try {
      // Group 2: photo is NOT saved — only used for comparison via Gemini
      final matches = await GarmentVisionService.instance.findTopMatches(
        imageBytes,
      );

      if (!mounted) return;

      if (matches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se encontraron prendas similares en el catálogo.',
            ),
            backgroundColor: AppTheme.cancelRed,
          ),
        );
        return;
      }

      if (matches.length == 1 || matches.first.confidence >= 0.85) {
        _applyProductFilter(matches.first.product);
      } else {
        _showMatchesDialog(matches);
      }
    } catch (e) {
      debugPrint('[ProductCatalog] AI recognition error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo identificar la prenda. Intente buscar manualmente.',
            ),
            backgroundColor: AppTheme.cancelRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecognizing = false);
    }
  }

  /// Filters the catalog to show the identified product.
  void _applyProductFilter(Map<String, dynamic> product) {
    final name = (product['name'] as String?) ?? '';
    final category = (product['category'] as String?) ?? '';
    setState(() {
      _searchQuery = name;
      if (_categories.contains(category)) {
        _selectedCategory = category;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Prenda identificada: $name'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMatchesDialog(List<GarmentMatch> matches) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Coincidencias encontradas',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Top ${matches.length} prendas más similares:',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: matches.map((m) {
                      final product = m.product;
                      final confidence = m.confidence * 100;
                      final reason = m.reason;
                      final imageUrl = (product['image_url'] as String?) ?? '';
                      final stock = (product['stock'] as int?) ?? 0;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _applyProductFilter(product);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.primary.withAlpha(80),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imageUrl.isNotEmpty
                                    ? CustomImageWidget(
                                        imageUrl: imageUrl,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        semanticLabel:
                                            'Imagen de ${product['name']}',
                                      )
                                    : Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withAlpha(30),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.checkroom_rounded,
                                          color: AppTheme.primary,
                                          size: 26,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (product['name'] as String?) ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      (product['category'] as String?) ?? '',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    if (reason.isNotEmpty)
                                      Text(
                                        reason,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${confidence.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Stock: $stock',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: stock <= 3
                                          ? AppTheme.cancelRed
                                          : AppTheme.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Buscar manualmente',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _retakePhoto() {
    setState(() {
      _capturedImageFile = null;
      _imageIsBase64 = false;
    });
  }

  Widget _buildCameraSection() {
    if (_capturedImageFile != null) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withAlpha(38),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildImagePreview(),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black.withAlpha(153),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _retakePhoto,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Foto capturada',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isRecognizing) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withAlpha(80)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Identificando prenda con IA...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    // Entire container tappable — height 180
    return GestureDetector(
      onTap: _isCameraLoading ? null : _takePhoto,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: AppTheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withAlpha(102), width: 2),
        ),
        child: _isCameraLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(38),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tomar foto',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '(Búsqueda rápida con IA)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_imageIsBase64 && _capturedImageFile is String) {
      final String dataUrl = _capturedImageFile as String;
      try {
        final String base64Data = dataUrl.contains(',')
            ? dataUrl.split(',').last
            : dataUrl;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          width: double.infinity,
          height: 300,
          fit: BoxFit.contain,
        );
      } catch (_) {}
    } else if (!kIsWeb && _capturedImageFile != null) {
      final xFile = _capturedImageFile as XFile;
      return Image.file(
        File(xFile.path),
        width: double.infinity,
        height: 300,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          color: AppTheme.primaryContainer,
          child: const Center(
            child: Icon(Icons.image_rounded, color: AppTheme.primary, size: 48),
          ),
        ),
      );
    }
    return Container(
      color: AppTheme.primaryContainer,
      child: const Center(
        child: Icon(Icons.image_rounded, color: AppTheme.primary, size: 48),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context),
      drawer: const AppNavigationDrawer(activeRoute: '/product-catalog-screen'),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'CATÁLOGO DE PRENDAS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Camera section
                  _buildCameraSection(),
                  const SizedBox(height: 12),
                  const Text(
                    'Búsqueda del Producto',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFCCCCCC),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      controller: TextEditingController(text: _searchQuery)
                        ..selection = TextSelection.collapsed(
                          offset: _searchQuery.length,
                        ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Category filter dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtrar por Categoría',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFCCCCCC),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _categories.contains(_selectedCategory)
                            ? _selectedCategory
                            : 'Todos',
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textSecondary,
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCategory = val);
                          }
                        },
                        items: _categories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text(cat),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Products grid
            Expanded(
              child: _isLoading
                  ? _buildSkeletonLoading()
                  : _filteredProducts.isEmpty
                  ? const Center(
                      child: Text(
                        'No se encontraron prendas',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppTheme.primary,
                      child: ProductCatalogGridWidget(
                        products: _filteredProducts,
                        onProductTap: (product) {
                          Navigator.pushNamed(
                            context,
                            '/product-detail-screen',
                            arguments: product,
                          ).then((_) => _loadData());
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.primary,
      elevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
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
    );
  }
}
