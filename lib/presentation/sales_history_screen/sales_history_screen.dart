import '../../core/app_export.dart';
import '../../services/app_state_notifier.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_navigation_drawer.dart';
import './widgets/sales_history_kpi_widget.dart';
import './widgets/sales_history_top_products_widget.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  DateTime _currentDate = DateTime.now();
  bool _isLandscape = false;
  bool _isLoading = false;

  List<Map<String, dynamic>> _currentSales = [];

  @override
  void initState() {
    super.initState();
    _loadSales();
    AppStateNotifier.instance.salesVersion.addListener(_onSalesChanged);
  }

  @override
  void dispose() {
    AppStateNotifier.instance.salesVersion.removeListener(_onSalesChanged);
    super.dispose();
  }

  void _onSalesChanged() {
    if (mounted) _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    final sales = await SupabaseService.instance.getSalesByDate(_currentDate);
    if (mounted) {
      setState(() {
        _currentSales = sales;
        _isLoading = false;
      });
    }
  }

  String get _formattedDate {
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const months = [
      '01',
      '02',
      '03',
      '04',
      '05',
      '06',
      '07',
      '08',
      '09',
      '10',
      '11',
      '12',
    ];
    final dayName = days[_currentDate.weekday - 1];
    final day = _currentDate.day.toString().padLeft(2, '0');
    final month = months[_currentDate.month - 1];
    final year = _currentDate.year;
    return '$dayName  $day/$month/$year';
  }

  void _prevDay() {
    setState(
      () => _currentDate = _currentDate.subtract(const Duration(days: 1)),
    );
    _loadSales();
  }

  void _nextDay() {
    setState(() => _currentDate = _currentDate.add(const Duration(days: 1)));
    _loadSales();
  }

  double get _totalPrecioVenta => _currentSales.fold(
    0.0,
    (s, e) => s + ((e['total_sale'] as num?)?.toDouble() ?? 0),
  );
  double get _totalCostoTotal => _currentSales.fold(
    0.0,
    (s, e) => s + ((e['total_cost'] as num?)?.toDouble() ?? 0),
  );
  double get _totalGananciaTotal => _totalPrecioVenta - _totalCostoTotal;

  /// Returns top-3 most sold products for the current day.
  List<Map<String, dynamic>> get _top3Vendidas {
    if (_currentSales.isEmpty) return [];
    final Map<String, Map<String, dynamic>> map = {};
    for (final s in _currentSales) {
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
    return sorted.take(3).toList();
  }

  /// Returns top-3 products by daily profit for the current day.
  List<Map<String, dynamic>> get _top3Ganancia {
    if (_currentSales.isEmpty) return [];
    final Map<String, Map<String, dynamic>> map = {};
    for (final s in _currentSales) {
      final name = (s['product_name'] as String?) ?? '';
      final imageUrl = (s['product_image_url'] as String?) ?? '';
      final gan =
          ((s['total_sale'] as num?)?.toDouble() ?? 0) -
          ((s['total_cost'] as num?)?.toDouble() ?? 0);
      if (!map.containsKey(name)) {
        map[name] = {'name': name, 'ganancia': 0.0, 'image_url': imageUrl};
      }
      map[name]!['ganancia'] = (map[name]!['ganancia'] as double) + gan;
    }
    final sorted = map.values.toList()
      ..sort(
        (a, b) => (b['ganancia'] as double).compareTo(a['ganancia'] as double),
      );
    return sorted.take(3).toList();
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
        IconButton(
          icon: Icon(
            _isLandscape
                ? Icons.stay_current_portrait_rounded
                : Icons.stay_current_landscape_rounded,
            color: Colors.white,
          ),
          tooltip: _isLandscape ? 'Vista vertical' : 'Vista horizontal',
          onPressed: () => setState(() => _isLandscape = !_isLandscape),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context),
      drawer: const AppNavigationDrawer(activeRoute: '/sales-history-screen'),
      body: SafeArea(child: _buildView()),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'HISTORIAL DE VENTAS',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        const Text(
          '(en soles)',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        _buildDateNav(),
      ],
    );
  }

  Widget _buildDateNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _NavBtn(icon: Icons.chevron_left_rounded, onTap: _prevDay),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
          ),
          child: Text(
            _formattedDate,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _NavBtn(icon: Icons.chevron_right_rounded, onTap: _nextDay),
      ],
    );
  }

  Widget _buildView() {
    final int totalUnits = _currentSales.fold(
      0,
      (s, e) => s + ((e['quantity'] as int?) ?? 0),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          SalesHistoryKpiWidget(
            totalRevenue: _totalPrecioVenta,
            totalUnits: totalUnits,
            dailyProfit: _totalGananciaTotal,
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_currentSales.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No hay ventas registradas para este día.',
                  style: TextStyle(color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            _buildSalesTable(),
            const SizedBox(height: 24),
            _buildSummaryTables(),
          ],
        ],
      ),
    );
  }

  Widget _buildSalesTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCCCCCC), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  _TableHeaderCell(text: 'Nro.\nItem', width: 36),
                  Container(
                    width: 1,
                    height: 38,
                    color: const Color(0xFFDDDDDD),
                  ),
                  _TableHeaderCell(text: 'Nombre del producto', width: 168),
                  Container(
                    width: 1,
                    height: 38,
                    color: const Color(0xFFCCCCCC),
                  ),
                  _TableHeaderCell(text: 'Cant.\n(und)', width: 52),
                  _TableHeaderCell(text: 'Precio\nVenta', width: 64),
                  _TableHeaderCell(text: 'Costo\nTotal', width: 64),
                  _TableHeaderCell(text: 'Gana\nTotal', width: 64),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFCCCCCC)),
            // Data rows
            ...List.generate(_currentSales.length, (i) {
              final s = _currentSales[i];
              final precioVenta = ((s['total_sale'] as num?)?.toDouble() ?? 0);
              final costoTotal = ((s['total_cost'] as num?)?.toDouble() ?? 0);
              final ganancia = precioVenta - costoTotal;
              final qty = (s['quantity'] as int?) ?? 0;
              final name = (s['product_name'] as String?) ?? '';
              final imageUrl =
                  (s['product_image_url'] as String?) ?? _getProductImage(name);
              return Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TableCell(text: '${i + 1}', width: 36, isCenter: true),
                        Container(width: 1, color: const Color(0xFFDDDDDD)),
                        _TableNameCell(
                          name: name,
                          imageUrl: imageUrl,
                          width: 168,
                        ),
                        Container(width: 1, color: const Color(0xFFCCCCCC)),
                        _TableCell(text: '$qty', width: 52, isCenter: true),
                        _TableCell(
                          text: precioVenta.toStringAsFixed(1),
                          width: 64,
                          isCenter: true,
                        ),
                        _TableCell(
                          text: costoTotal.toStringAsFixed(1),
                          width: 64,
                          isCenter: true,
                        ),
                        _TableCell(
                          text: ganancia.toStringAsFixed(1),
                          width: 64,
                          isCenter: true,
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: const Color(0xFFEEEEEE)),
                ],
              );
            }),
            // Totals row
            Container(
              color: const Color(0xFFF9F9F9),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TableCell(text: '', width: 36),
                    Container(width: 1, color: const Color(0xFFDDDDDD)),
                    _TableCell(text: '', width: 168),
                    Container(width: 1, color: const Color(0xFFCCCCCC)),
                    _TableCell(text: '', width: 52),
                    _TableCell(
                      text: _totalPrecioVenta.toStringAsFixed(1),
                      width: 64,
                      isCenter: true,
                      bold: true,
                    ),
                    _TableCell(
                      text: _totalCostoTotal.toStringAsFixed(1),
                      width: 64,
                      isCenter: true,
                      bold: true,
                    ),
                    _TableCell(
                      text: _totalGananciaTotal.toStringAsFixed(1),
                      width: 64,
                      isCenter: true,
                      bold: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTables() {
    return SalesHistoryTopProductsWidget(
      topVendidas: _top3Vendidas,
      topGanancia: _top3Ganancia,
    );
  }
}

// Helper
String _getProductImage(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('polo') ||
      lower.contains('lacoste') ||
      lower.contains('tommy') ||
      lower.contains('robinson')) {
    return 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=80&q=70';
  } else if (lower.contains('jean') || lower.contains('short jean')) {
    return 'https://images.unsplash.com/photo-1542272604-787c3835535d?w=80&q=70';
  } else if (lower.contains('casaca') || lower.contains('adidas')) {
    return 'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=80&q=70';
  } else if (lower.contains('vestido')) {
    return 'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=80&q=70';
  } else if (lower.contains('blusa')) {
    return 'https://images.unsplash.com/photo-1564257631407-4deb1f99d992?w=80&q=70';
  }
  return 'https://images.pexels.com/photos/996329/pexels-photo-996329.jpeg?w=80&q=70';
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primary,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String text;
  final double? width;
  const _TableHeaderCell({required this.text, this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final double? width;
  final bool isCenter;
  final bool bold;
  const _TableCell({
    required this.text,
    this.width,
    this.isCenter = false,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textPrimary,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
          textAlign: isCenter ? TextAlign.center : TextAlign.left,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
    );
  }
}

class _TableNameCell extends StatelessWidget {
  final String name;
  final String imageUrl;
  final double width;

  const _TableNameCell({
    required this.name,
    required this.imageUrl,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CustomImageWidget(
                imageUrl: imageUrl,
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                semanticLabel: 'Imagen del producto $name',
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
