import '../../core/app_export.dart';
import '../../services/app_state_notifier.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_navigation_drawer.dart';
import './widgets/existing_product_results_widget.dart';
import './widgets/existing_product_search_widget.dart';
import './widgets/existing_product_update_form_widget.dart';

class ExistingProductEntryScreen extends StatefulWidget {
  const ExistingProductEntryScreen({super.key});

  @override
  State<ExistingProductEntryScreen> createState() =>
      _ExistingProductEntryScreenState();
}

class _ExistingProductEntryScreenState
    extends State<ExistingProductEntryScreen> {
  Map<String, dynamic>? _selectedProduct;
  String _searchQuery = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _allProducts = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    AppStateNotifier.instance.productsVersion.addListener(_onProductsChanged);
  }

  @override
  void dispose() {
    AppStateNotifier.instance.productsVersion.removeListener(
      _onProductsChanged,
    );
    super.dispose();
  }

  void _onProductsChanged() {
    if (mounted && _selectedProduct == null) _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await SupabaseService.instance.getProducts();
    if (mounted) {
      setState(() {
        _allProducts = products.map((p) => _normalizeProduct(p)).toList();
        _isLoading = false;
      });
    }
  }

  /// Normalizes raw Supabase product keys to the keys expected by widgets.
  Map<String, dynamic> _normalizeProduct(Map<String, dynamic> p) {
    final imageUrl =
        (p['image_url'] as String?) ?? (p['imageUrl'] as String?) ?? '';
    final stock = (p['stock'] as int?) ?? (p['quantity'] as int?) ?? 0;
    return {
      ...p,
      'imageUrl': imageUrl,
      'image_url': imageUrl,
      'quantity': stock,
      'stock': stock,
      'semanticLabel': 'Imagen de ${(p['name'] as String?) ?? 'producto'}',
    };
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.isEmpty) return _allProducts;
    final q = _searchQuery.toLowerCase();
    return _allProducts
        .where(
          (p) =>
              ((p['name'] as String?) ?? '').toLowerCase().contains(q) ||
              ((p['category'] as String?) ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  void _onProductSelected(Map<String, dynamic> product) {
    setState(() => _selectedProduct = product);
  }

  void _onClearSelection() {
    setState(() => _selectedProduct = null);
    _loadProducts();
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context),
      drawer: const AppNavigationDrawer(
        activeRoute: '/existing-product-entry-screen',
      ),
      body: SafeArea(
        child: _selectedProduct != null
            ? ExistingProductUpdateFormWidget(
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
                      'INGRESAR PRENDAS EXISTENTES',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ExistingProductSearchWidget(
                      onSearchChanged: _onSearchChanged,
                      searchQuery: _searchQuery,
                      onProductFound: _onProductSelected,
                    ),
                    const SizedBox(height: 16),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ExistingProductResultsWidget(
                            products: _filteredProducts,
                            onProductSelected: _onProductSelected,
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
}
