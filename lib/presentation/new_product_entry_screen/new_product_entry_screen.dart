import '../../core/app_export.dart';
import '../../widgets/app_navigation_drawer.dart';
import './widgets/new_product_camera_widget.dart';
import './widgets/new_product_form_widget.dart';

class NewProductEntryScreen extends StatefulWidget {
  const NewProductEntryScreen({super.key});

  @override
  State<NewProductEntryScreen> createState() => _NewProductEntryScreenState();
}

class _NewProductEntryScreenState extends State<NewProductEntryScreen> {
  // TODO: Replace with Riverpod/Bloc for production
  dynamic _capturedImageFile; // XFile on mobile, String base64 on web
  bool _imageIsBase64 = false;

  void _onImageCaptured(dynamic imageFile, {bool isBase64 = false}) {
    setState(() {
      _capturedImageFile = imageFile;
      _imageIsBase64 = isBase64;
    });
  }

  void _onRetakePhoto() {
    setState(() {
      _capturedImageFile = null;
      _imageIsBase64 = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context),
      drawer: const AppNavigationDrawer(
        activeRoute: '/new-product-entry-screen',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen title
              const Text(
                'INGRESO DE PRENDAS NUEVAS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Camera section
              NewProductCameraWidget(
                capturedImageFile: _capturedImageFile,
                imageIsBase64: _imageIsBase64,
                onImageCaptured: _onImageCaptured,
                onRetake: _onRetakePhoto,
              ),

              const SizedBox(height: 20),

              // Form section
              NewProductFormWidget(capturedImageFile: _capturedImageFile),
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
}
