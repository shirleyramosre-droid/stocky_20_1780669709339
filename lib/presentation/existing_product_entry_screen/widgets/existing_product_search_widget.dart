import 'dart:convert';
import 'dart:io' if (dart.library.io) 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_export.dart';
import '../../../services/garment_vision_service.dart';

class ExistingProductSearchWidget extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Map<String, dynamic>>? onProductFound;

  const ExistingProductSearchWidget({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    this.onProductFound,
  });

  @override
  State<ExistingProductSearchWidget> createState() =>
      _ExistingProductSearchWidgetState();
}

class _ExistingProductSearchWidgetState
    extends State<ExistingProductSearchWidget> {
  dynamic _capturedImageFile;
  bool _imageIsBase64 = false;
  bool _isCameraLoading = false;
  bool _isRecognizing = false;
  final ImagePicker _picker = ImagePicker();

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
      // Group 2: photo is NOT saved — only used for comparison
      await _recognizeProductFromImage(bytes);
    }
  }

  Future<void> _recognizeProductFromImage(Uint8List imageBytes) async {
    if (!mounted) return;
    setState(() => _isRecognizing = true);

    try {
      // Use Gemini via GarmentVisionService — returns top 3 matches
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

      // Auto-select if single match or very high confidence
      if (matches.length == 1 || matches.first.confidence >= 0.85) {
        _autoSelectProduct(matches.first.product);
      } else {
        _showMatchesDialog(matches);
      }
    } catch (e) {
      debugPrint('[ExistingProductSearch] AI recognition error: $e');
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

  void _autoSelectProduct(Map<String, dynamic> product) {
    final name = (product['name'] as String?) ?? '';
    widget.onSearchChanged(name);
    if (widget.onProductFound != null) {
      widget.onProductFound!(product);
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
                          _autoSelectProduct(product);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCameraSection(),
        const SizedBox(height: 12),
        // Search field below the camera button
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            onChanged: widget.onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Búsqueda del Producto',
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppTheme.textMuted,
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
