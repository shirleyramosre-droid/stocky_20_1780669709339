import 'dart:io' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../theme/app_theme.dart';

class NewProductCameraWidget extends StatefulWidget {
  final dynamic capturedImageFile;
  final bool imageIsBase64;
  final Function(dynamic imageFile, {bool isBase64}) onImageCaptured;
  final VoidCallback onRetake;

  const NewProductCameraWidget({
    super.key,
    required this.capturedImageFile,
    required this.imageIsBase64,
    required this.onImageCaptured,
    required this.onRetake,
  });

  @override
  State<NewProductCameraWidget> createState() => _NewProductCameraWidgetState();
}

class _NewProductCameraWidgetState extends State<NewProductCameraWidget> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _takePhoto() async {
    setState(() => _isLoading = true);
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo != null) {
        await _cropAndReturn(photo);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isLoading = true);
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        await _cropAndReturn(image);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cropAndReturn(XFile file) async {
    try {
      if (kIsWeb) {
        // Web: skip crop, use directly
        final bytes = await file.readAsBytes();
        final base64Str = 'data:image/jpeg;base64,${_bytesToBase64(bytes)}';
        widget.onImageCaptured(base64Str, isBase64: true);
        return;
      }
      // Mobile: offer crop
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
        final xFile = XFile(croppedFile.path);
        widget.onImageCaptured(xFile, isBase64: false);
      }
    } catch (_) {
      // If crop fails, use original
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final base64Str = 'data:image/jpeg;base64,${_bytesToBase64(bytes)}';
        widget.onImageCaptured(base64Str, isBase64: true);
      } else {
        widget.onImageCaptured(file, isBase64: false);
      }
    }
  }

  String _bytesToBase64(Uint8List bytes) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final result = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final b0 = bytes[i];
      final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      result.write(chars[(b0 >> 2) & 0x3F]);
      result.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      result.write(
        i + 1 < bytes.length ? chars[((b1 << 2) | (b2 >> 6)) & 0x3F] : '=',
      );
      result.write(i + 2 < bytes.length ? chars[b2 & 0x3F] : '=');
    }
    return result.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.capturedImageFile != null) {
      return _buildPreview();
    }
    return _buildCaptureButton();
  }

  Widget _buildCaptureButton() {
    // Entire container is tappable — height 1.5x original (120 → 180)
    return GestureDetector(
      onTap: _isLoading ? null : _showPhotoOptions,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: AppTheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withAlpha(102), width: 2),
        ),
        child: _isLoading
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
                ],
              ),
      ),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: AppTheme.primary,
              ),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppTheme.primary,
              ),
              title: const Text('Elegir de galería'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
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
            child: _buildImageWidget(),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black.withAlpha(153),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: widget.onRetake,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }

  Widget _buildImageWidget() {
    if (kIsWeb && widget.imageIsBase64 && widget.capturedImageFile is String) {
      final String dataUrl = widget.capturedImageFile as String;
      final String base64Data = dataUrl.contains(',')
          ? dataUrl.split(',').last
          : dataUrl;
      try {
        final bytes = Uri.parse(dataUrl).data?.contentAsBytes();
        if (bytes != null) {
          return Image.memory(
            bytes,
            width: double.infinity,
            height: 300,
            fit: BoxFit.contain,
          );
        }
      } catch (_) {}
      return Container(
        color: AppTheme.primaryContainer,
        child: const Center(
          child: Icon(Icons.image_rounded, color: AppTheme.primary, size: 48),
        ),
      );
    } else if (!kIsWeb && widget.capturedImageFile != null) {
      final xFile = widget.capturedImageFile as XFile;
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
}
