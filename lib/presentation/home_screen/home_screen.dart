import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_navigation_drawer.dart';
import './widgets/home_kpi_strip_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late List<AnimationController> _entranceControllers;
  late List<Animation<double>> _entranceAnimations;

  bool _ingresoExpanded = false;
  bool _adminExpanded = false;

  // 5 items: 4 action buttons + 1 history card
  static const int _entranceCount = 5;

  @override
  void initState() {
    super.initState();
    _entranceControllers = List.generate(
      _entranceCount,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _entranceAnimations = _entranceControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOutCubic))
        .toList();

    for (int i = 0; i < _entranceCount; i++) {
      final delay = 80 + (i * 60);
      Future.microtask(() async {
        await Future.delayed(Duration(milliseconds: delay));
        if (mounted) _entranceControllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _entranceControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context),
      drawer: const AppNavigationDrawer(activeRoute: '/home-screen'),
      body: SafeArea(
        child: Column(
          children: [
            const HomeKpiStripWidget(),
            Expanded(child: _buildGrid()),
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
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
          tooltip: 'Menú',
        ),
      ),
      title: Image.asset(
        'assets/images/Gemini_Generated_Image_49wjgn49wjgn49wj-Photoroom-1780793613527.png',
        height: 40,
        fit: BoxFit.contain,
        semanticLabel: 'Logo Stocky',
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(64),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Row 1: INGRESAR PRENDAS + REGISTRAR VENTA
        _buildEntranceWrapper(
          index: 0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ExpandableActionButton(
                  label: 'INGRESAR\nPRENDAS',
                  icon: Icons.add_circle_outline_rounded,
                  color: const Color(0xFF1565C0),
                  isExpanded: _ingresoExpanded,
                  onTap: () =>
                      setState(() => _ingresoExpanded = !_ingresoExpanded),
                  subItems: [
                    _SubItem(
                      label: 'INGRESO DE PRENDAS NUEVAS',
                      icon: Icons.add_box_rounded,
                      onTap: () {
                        setState(() => _ingresoExpanded = false);
                        Navigator.pushNamed(
                          context,
                          '/new-product-entry-screen',
                        );
                      },
                    ),
                    _SubItem(
                      label: 'INGRESO DE PRENDAS EXISTENTES',
                      icon: Icons.inventory_2_rounded,
                      onTap: () {
                        setState(() => _ingresoExpanded = false);
                        Navigator.pushNamed(
                          context,
                          '/existing-product-entry-screen',
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigActionButton(
                  label: 'REGISTRAR\nVENTA',
                  icon: Icons.shopping_cart_rounded,
                  color: const Color(0xFF2E7D32),
                  onTap: () =>
                      Navigator.pushNamed(context, '/register-sale-screen'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Row 2: ADMINISTRAR CATEGORÍAS + CATÁLOGO
        _buildEntranceWrapper(
          index: 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ExpandableActionButton(
                  label: 'ADMINISTRAR\nCATEGORÍAS',
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFFE91E8C),
                  isExpanded: _adminExpanded,
                  onTap: () => setState(() => _adminExpanded = !_adminExpanded),
                  subItems: [
                    _SubItem(
                      label: 'CONFIGURAR CATEGORÍA',
                      icon: Icons.category_rounded,
                      onTap: () {
                        setState(() => _adminExpanded = false);
                        Navigator.pushNamed(
                          context,
                          '/configure-category-screen',
                        );
                      },
                    ),
                    _SubItem(
                      label: 'ALERTAS DE STOCK POR CATEGORÍA',
                      icon: Icons.warning_amber_rounded,
                      onTap: () {
                        setState(() => _adminExpanded = false);
                        Navigator.pushNamed(context, '/stock-alerts-screen');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigActionButton(
                  label: 'CATÁLOGO',
                  icon: Icons.local_offer_rounded,
                  color: const Color(0xFF7B1FA2),
                  onTap: () =>
                      Navigator.pushNamed(context, '/product-catalog-screen'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Full-width HISTORIAL DE VENTAS card
        _buildEntranceWrapper(
          index: 2,
          child: _SalesHistoryCard(
            onTap: () => Navigator.pushNamed(context, '/sales-history-screen'),
          ),
        ),
      ],
    );
  }

  Widget _buildEntranceWrapper({required int index, required Widget child}) {
    final safeIndex = index.clamp(0, _entranceCount - 1);
    return FadeTransition(
      opacity: _entranceAnimations[safeIndex],
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(_entranceAnimations[safeIndex]),
        child: child,
      ),
    );
  }
}

// ── Expandable action button ───────────────────────────────────────────────

class _SubItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SubItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _ExpandableActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isExpanded;
  final VoidCallback onTap;
  final List<_SubItem> subItems;

  const _ExpandableActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isExpanded,
    required this.onTap,
    required this.subItems,
  });

  @override
  State<_ExpandableActionButton> createState() =>
      _ExpandableActionButtonState();
}

class _ExpandableActionButtonState extends State<_ExpandableActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main button
        ScaleTransition(
          scale: _scale,
          child: GestureDetector(
            onTapDown: (_) => _ctrl.reverse(),
            onTapUp: (_) {
              _ctrl.forward();
              widget.onTap();
            },
            onTapCancel: () => _ctrl.forward(),
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: widget.isExpanded
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      )
                    : BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withAlpha(100),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    widget.isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withAlpha(200),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Dropdown sub-items
        if (widget.isExpanded)
          Container(
            decoration: BoxDecoration(
              color: widget.color.withAlpha(230),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withAlpha(80),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: widget.subItems.map((item) {
                return InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(40),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item.icon, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ── Big action button ──────────────────────────────────────────────────────

class _BigActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BigActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_BigActionButton> createState() => _BigActionButtonState();
}

class _BigActionButtonState extends State<_BigActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.forward();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.forward(),
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha(100),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 36),
              const SizedBox(height: 10),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sales History Card ─────────────────────────────────────────────────────

class _SalesHistoryCard extends StatefulWidget {
  final VoidCallback onTap;
  const _SalesHistoryCard({required this.onTap});

  @override
  State<_SalesHistoryCard> createState() => _SalesHistoryCardState();
}

class _SalesHistoryCardState extends State<_SalesHistoryCard> {
  List<Map<String, dynamic>> _topProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopProducts();
  }

  Future<void> _loadTopProducts() async {
    try {
      final sales = await SupabaseService.instance.getSalesByDate(
        DateTime.now(),
      );
      final Map<String, Map<String, dynamic>> map = {};
      for (final s in sales) {
        final name = (s['product_name'] as String?) ?? '';
        final imageUrl = (s['product_image_url'] as String?) ?? '';
        if (!map.containsKey(name)) {
          map[name] = {'name': name, 'qty': 0, 'image_url': imageUrl};
        }
        map[name]!['qty'] =
            (map[name]!['qty'] as int) + ((s['quantity'] as int?) ?? 0);
      }
      final sorted = map.values.toList()
        ..sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));
      if (mounted) {
        setState(() {
          _topProducts = sorted.take(3).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getFallbackImage(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('polo') || lower.contains('lacoste')) {
      return 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=80&q=70';
    } else if (lower.contains('jean')) {
      return 'https://images.unsplash.com/photo-1542272604-787c3835535d?w=80&q=70';
    } else if (lower.contains('casaca')) {
      return 'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=80&q=70';
    }
    return 'https://images.pexels.com/photos/996329/pexels-photo-996329.jpeg?w=80&q=70';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE0A0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withAlpha(30),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'HISTORIAL DE VENTAS',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onTap,
                  child: const Row(
                    children: [
                      Text(
                        'Más Vendidos',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFB45309),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Products horizontal list
            if (_isLoading)
              const Center(
                child: SizedBox(
                  height: 80,
                  child: CircularProgressIndicator(
                    color: Color(0xFFB45309),
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_topProducts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No hay ventas registradas hoy',
                  style: TextStyle(fontSize: 13, color: Color(0xFFB45309)),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _topProducts.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final p = entry.value;
                    final name = (p['name'] as String?) ?? '';
                    final imageUrl = (p['image_url'] as String?) ?? '';
                    final displayUrl = imageUrl.isNotEmpty
                        ? imageUrl
                        : _getFallbackImage(name);
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CustomImageWidget(
                                  imageUrl: displayUrl,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                  semanticLabel: 'Imagen de $name',
                                ),
                              ),
                              Positioned(
                                top: 0,
                                left: 0,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: rank == 1
                                        ? const Color(0xFFFFD700)
                                        : rank == 2
                                        ? const Color(0xFFC0C0C0)
                                        : const Color(0xFFCD7F32),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$rank',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
