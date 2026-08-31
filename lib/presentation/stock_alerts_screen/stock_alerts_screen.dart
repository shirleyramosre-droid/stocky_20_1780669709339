import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_navigation_drawer.dart';

class StockAlertsScreen extends StatefulWidget {
  const StockAlertsScreen({super.key});

  @override
  State<StockAlertsScreen> createState() => _StockAlertsScreenState();
}

class _StockAlertsScreenState extends State<StockAlertsScreen> {
  String _selectedCategory = '';
  int _casiAgotado = 0;
  int _optimo = 0;

  late TextEditingController _casiAgotadoController;
  late TextEditingController _optimoController;

  List<String> _categories = [];

  // Map to store saved values per category
  final Map<String, Map<String, int>> _savedValues = {};

  @override
  void initState() {
    super.initState();
    _casiAgotadoController = TextEditingController(text: '0');
    _optimoController = TextEditingController(text: '0');
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await SupabaseService.instance.getCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        if (_categories.isNotEmpty && _selectedCategory.isEmpty) {
          _selectedCategory = _categories.first;
          _loadCategoryValues(_selectedCategory);
        }
      });
    }
  }

  @override
  void dispose() {
    _casiAgotadoController.dispose();
    _optimoController.dispose();
    super.dispose();
  }

  void _loadCategoryValues(String category) {
    if (_savedValues.containsKey(category)) {
      _casiAgotado = _savedValues[category]!['casiAgotado']!;
      _optimo = _savedValues[category]!['optimo']!;
    } else {
      _casiAgotado = 0;
      _optimo = 0;
    }
    _casiAgotadoController.text = '$_casiAgotado';
    _optimoController.text = '$_optimo';
  }

  // "Queda poco" range: casiAgotado+1 to optimo-1
  String get _quedaPocoText {
    final low = _casiAgotado + 1;
    final high = _optimo - 1;
    if (high < low) return '—';
    return '$low a $high';
  }

  bool get _quedaPocoValid => (_optimo - 1) >= (_casiAgotado + 1);

  void _onCategoryChanged(String? val) {
    if (val == null) return;
    setState(() {
      _selectedCategory = val;
      _loadCategoryValues(val);
    });
  }

  void _increment(String field) {
    setState(() {
      if (field == 'casiAgotado') {
        _casiAgotado++;
        _casiAgotadoController.text = '$_casiAgotado';
      } else {
        _optimo++;
        _optimoController.text = '$_optimo';
      }
    });
  }

  void _decrement(String field) {
    setState(() {
      if (field == 'casiAgotado') {
        if (_casiAgotado > 0) {
          _casiAgotado--;
          _casiAgotadoController.text = '$_casiAgotado';
        }
      } else {
        if (_optimo > 0) {
          _optimo--;
          _optimoController.text = '$_optimo';
        }
      }
    });
  }

  void _onCasiAgotadoTyped(String val) {
    final parsed = int.tryParse(val);
    if (parsed != null && parsed >= 0) setState(() => _casiAgotado = parsed);
  }

  void _onOptimoTyped(String val) {
    final parsed = int.tryParse(val);
    if (parsed != null && parsed >= 0) setState(() => _optimo = parsed);
  }

  Future<bool> _onWillPop() async {
    final result = await _showExitDialog();
    return result ?? false;
  }

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: Color(0xFFF5A623),
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '¿Seguro que deseas salir?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Si lo hace perderá todo su progreso',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'SÍ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cancelRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'NO',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onCancel() async {
    final exit = await _showExitDialog();
    if (exit == true && mounted) Navigator.pop(context);
  }

  void _onSave() async {
    if (_selectedCategory.isEmpty) return;
    if (!_quedaPocoValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El valor Óptimo debe ser mayor que Casi agotado + 1'),
          backgroundColor: AppTheme.cancelRed,
        ),
      );
      return;
    }
    setState(() {
      _savedValues[_selectedCategory] = {
        'casiAgotado': _casiAgotado,
        'optimo': _optimo,
      };
    });
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppTheme.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Se han registrado las alertas de stock',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'ACEPTAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _buildAppBar(context),
        drawer: const AppNavigationDrawer(activeRoute: '/stock-alerts-screen'),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title — updated
                      const Text(
                        'ALERTAS DE STOCK POR CATEGORÍA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Category dropdown
                      const Text(
                        'Categoría',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
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
                                : null,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppTheme.textSecondary,
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                            ),
                            onChanged: _onCategoryChanged,
                            items: _categories.map((cat) {
                              return DropdownMenuItem<String>(
                                value: cat,
                                child: Text(cat),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Casi agotado row
                      _buildStockRow(
                        label: 'Casi agotado',
                        labelColor: const Color(0xFFD32F2F),
                        suffix: 'menos o igual a',
                        value: _casiAgotado,
                        controller: _casiAgotadoController,
                        isReadOnly: false,
                        onDecrement: () => _decrement('casiAgotado'),
                        onIncrement: () => _increment('casiAgotado'),
                        onTyped: _onCasiAgotadoTyped,
                      ),
                      const SizedBox(height: 16),
                      // Queda poco row (auto-filled, read-only)
                      _buildStockRowRange(
                        label: 'Queda poco',
                        labelColor: const Color(0xFFF9A825),
                        labelTextColor: Colors.black,
                        suffix: 'entre',
                        rangeText: _quedaPocoText,
                      ),
                      const SizedBox(height: 16),
                      // Óptimo row
                      _buildStockRow(
                        label: 'Óptimo',
                        labelColor: const Color(0xFF2E7D32),
                        suffix: 'más o igual de',
                        value: _optimo,
                        controller: _optimoController,
                        isReadOnly: false,
                        onDecrement: () => _decrement('optimo'),
                        onIncrement: () => _increment('optimo'),
                        onTyped: _onOptimoTyped,
                      ),
                      const SizedBox(height: 32),

                      // ── Registros table ──
                      if (_categories.isNotEmpty) ...[
                        const Text(
                          'Registros',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildRegistrosTable(),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
              // Bottom buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _onCancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cancelRed,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: const Text(
                          'CANCELAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: const Text(
                          'GUARDAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrosTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _categories.asMap().entries.map((entry) {
          final i = entry.key;
          final cat = entry.value;
          final isLast = i == _categories.length - 1;
          final hasData = _savedValues.containsKey(cat);

          return Column(
            children: [
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: const Color(0xFFEEEEEE),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Category name
                    Expanded(
                      flex: 2,
                      child: Text(
                        cat,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    // Thresholds or "Cant. No Regist."
                    if (!hasData)
                      const Text(
                        'Cant. No Regist.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD32F2F),
                        ),
                      )
                    else ...[
                      // Casi agotado
                      Text(
                        '${_savedValues[cat]!['casiAgotado']}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD32F2F),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Queda poco (range)
                      Builder(
                        builder: (ctx) {
                          final ca = _savedValues[cat]!['casiAgotado']!;
                          final op = _savedValues[cat]!['optimo']!;
                          final low = ca + 1;
                          final high = op - 1;
                          final rangeText = high >= low ? '$low a $high' : '—';
                          return Text(
                            rangeText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF9A825),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      // Óptimo
                      Text(
                        '${_savedValues[cat]!['optimo']}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStockRow({
    required String label,
    required Color labelColor,
    required String suffix,
    required int value,
    required TextEditingController controller,
    required bool isReadOnly,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required ValueChanged<String> onTyped,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: labelColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          suffix,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const Spacer(),
        Row(
          children: [
            _counterButton(Icons.remove, onDecrement),
            SizedBox(
              width: 48,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onChanged: onTyped,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ),
            _counterButton(Icons.add, onIncrement),
          ],
        ),
      ],
    );
  }

  Widget _buildStockRowRange({
    required String label,
    required Color labelColor,
    Color labelTextColor = Colors.white,
    required String suffix,
    required String rangeText,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: labelColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: labelTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          suffix,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const Spacer(),
        Text(
          rangeText,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFEEEEEE),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppTheme.textPrimary),
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
