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
import './widgets/register_sale_form_widget.dart';
import './widgets/register_sale_search_widget.dart';

class RegisterSaleScreen extends StatefulWidget {
  const RegisterSaleScreen({super.key});

  @override
  State<RegisterSaleScreen> createState() => _RegisterSaleScreenState();
}

class _RegisterSaleScreenState extends State<RegisterSaleScreen> {
  Map<String, dynamic>? _selectedProduct;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  // Camera state
  dynamic _capturedImageFile;
  bool _imageIsBase64 = false;
  bool _isCameraLoading = false;
  bool _isRecognizing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    AppStateNotifier.instance.productsVersion.addListener(_onProductsChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    AppStateNotifier.instance.productsVersion.removeListener(
      _onProductsChanged,
    );
    super.dispose();
  }

  void _onProductsChanged() {
    if (mounted && _searchQuery.isNotEmpty) {
      _onSearchChanged(_searchQuery);
    }
  }

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

  Future<void> _pickFromGallery() async {
    setState(() => _isCameraLoading = true);
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        await _cropAndProcess(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo acceder a la galería.'),
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

  void _showPhotoOptions() {
    // Only allow taking photo in the moment — no gallery option
    _takePhoto();
  }

  /// Uses Gemini vision (via GarmentVisionService) to identify the garment
  /// and match it against the Supabase catalog. Photo is NOT saved.
  Future<void> _recognizeProductFromImage(Uint8List imageBytes) async {
    if (!mounted) return;
    setState(() => _isRecognizing = true);

    try {
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
        _onProductSelected(matches.first.product);
      } else {
        _showMatchesDialog(matches);
      }
    } catch (e) {
      debugPrint('[RegisterSale] AI recognition error: $e');
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
                          _onProductSelected(product);
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
      onTap: _isCameraLoading ? null : _showPhotoOptions,
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

  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.isEmpty) return [];
    return _searchResults;
  }

  void _onProductSelected(Map<String, dynamic> product) {
    setState(() => _selectedProduct = product);
  }

  void _onClearSelection() {
    setState(() {
      _selectedProduct = null;
      _searchQuery = '';
      _searchController.clear();
      _searchResults = [];
      _capturedImageFile = null;
      _imageIsBase64 = false;
    });
  }

  Future<bool> _onWillPop() async {
    if (_selectedProduct == null && _searchQuery.isEmpty) return true;
    return await _showExitDialog() ?? false;
  }

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.help_outline_rounded,
                  color: Color(0xFFF9A825),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '¿Seguro que desea salir?\nSi lo hace perderá todo su progreso',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
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
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
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
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _buildAppBar(context),
        drawer: const AppNavigationDrawer(activeRoute: '/register-sale-screen'),
        body: SafeArea(
          child: _selectedProduct != null
              ? RegisterSaleFormWidget(
                  product: _selectedProduct!,
                  onCancel: _onClearSelection,
                  onSaved: _onClearSelection,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'REGISTRAR VENTAS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCameraSection(),
                      const SizedBox(height: 16),
                      RegisterSaleSearchWidget(
                        controller: _searchController,
                        onSearchChanged: _onSearchChanged,
                        searchQuery: _searchQuery,
                      ),
                      const SizedBox(height: 16),
                      if (_isSearching)
                        const Center(child: CircularProgressIndicator())
                      else if (_searchQuery.isNotEmpty &&
                          _filteredProducts.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No se encontraron productos',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._filteredProducts.map(
                          (product) => _buildProductCard(product),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _onSearchChanged(String query) async {
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
    });
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    final results = await SupabaseService.instance.searchProducts(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final String name = (product['name'] as String?) ?? '';
    final String category = (product['category'] as String?) ?? '';
    final String? size = product['size'] as String?;
    final int qty = (product['stock'] as int?) ?? 0;
    final String imageUrl = (product['image_url'] as String?) ?? '';

    return GestureDetector(
      onTap: () => _onProductSelected(product),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl.isNotEmpty
                  ? CustomImageWidget(
                      imageUrl: imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                      semanticLabel: 'Imagen de $name',
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.checkroom_rounded,
                        color: AppTheme.primary,
                        size: 30,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  if (size != null && size.isNotEmpty)
                    Text(
                      'Talla: $size',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock: $qty und.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: qty <= 3 ? AppTheme.cancelRed : AppTheme.success,
                    ),
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
    );
  }
}
