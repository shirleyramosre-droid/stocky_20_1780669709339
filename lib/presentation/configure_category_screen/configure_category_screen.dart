import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation_drawer.dart';
import '../../services/supabase_service.dart';

class ConfigureCategoryScreen extends StatefulWidget {
  const ConfigureCategoryScreen({super.key});

  @override
  State<ConfigureCategoryScreen> createState() =>
      _ConfigureCategoryScreenState();
}

class _ConfigureCategoryScreenState extends State<ConfigureCategoryScreen> {
  // 0 = none selected, 1 = editar, 2 = agregar, 3 = ocultar
  int _selectedSection = 0;

  List<String> _categories = [];
  bool _isLoadingCategories = true;

  // EDITAR section state
  String? _editSelectedCategory;
  final TextEditingController _editNewNameCtrl = TextEditingController();
  final bool _editTodos = true;

  // AGREGAR section state
  final TextEditingController _addNameCtrl = TextEditingController();

  // OCULTAR section state
  String? _ocultarSelectedCategory;

  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
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
    _editNewNameCtrl.dispose();
    _addNameCtrl.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    final result = await _showExitDialog();
    return result ?? false;
  }

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        icon: Icons.help_outline_rounded,
        iconColor: const Color(0xFFE6A817),
        message:
            '¿Seguro que desea salir?\nSi lo hace perderá todo su progreso',
        onYes: () => Navigator.pop(ctx, true),
        onNo: () => Navigator.pop(ctx, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
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
        ),
        drawer: const AppNavigationDrawer(
          activeRoute: '/configure-category-screen',
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'CONFIGURAR CATEGORÍA',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'CATEGORÍAS ACTUALES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                _isLoadingCategories
                    ? const Center(child: CircularProgressIndicator())
                    : _buildCategoriesList(),
                const SizedBox(height: 20),
                _buildEditarSection(),
                const SizedBox(height: 16),
                _buildAgregarSection(),
                const SizedBox(height: 16),
                _buildOcultarSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesList() {
    if (_categories.isEmpty) {
      return const Text(
        'No hay categorías registradas.',
        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCCCCCC), width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: _categories.map((cat) {
          final isLast = cat == _categories.last;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(
                      bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                    ),
            ),
            child: Text(
              cat,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── SECTION 1: EDITAR ──────────────────────────────────────────────────────
  Widget _buildEditarSection() {
    final isActive = _selectedSection == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _selectedSection = isActive ? 0 : 1;
            _markChanged();
          }),
          child: Row(
            children: [
              Radio<int>(
                value: 1,
                groupValue: _selectedSection,
                onChanged: (v) => setState(() {
                  _selectedSection = v!;
                  _markChanged();
                }),
                activeColor: AppTheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const Text(
                'EDITAR NOMBRE DE CATEGORÍA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (isActive) ...[
          const SizedBox(height: 8),
          const Text(
            'Nombre Actual de Categoría',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          _buildDropdown(
            value: _editSelectedCategory,
            hint: '',
            items: _categories,
            onChanged: (v) => setState(() {
              _editSelectedCategory = v;
              _markChanged();
            }),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nuevo Nombre de Categoría',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _editNewNameCtrl,
            onChanged: (_) => _markChanged(),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _ActionBtn(
              label: 'CAMBIAR',
              color: AppTheme.primary,
              onTap: _onCambiarTap,
            ),
          ),
        ],
      ],
    );
  }

  void _onCambiarTap() {
    if (_editSelectedCategory == null || _editNewNameCtrl.text.trim().isEmpty) {
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        icon: Icons.help_outline_rounded,
        iconColor: const Color(0xFFE6A817),
        message:
            '¿Seguro de cambiar el nombre?\nEste cambio afectará a todos los productos que pertenecen actualmente a esta categoría',
        onYes: () {
          Navigator.pop(ctx);
          _doEditCategory();
        },
        onNo: () => Navigator.pop(ctx),
      ),
    );
  }

  Future<void> _doEditCategory() async {
    final newName = _editNewNameCtrl.text.trim();
    final success = await SupabaseService.instance.renameCategory(
      _editSelectedCategory!,
      newName,
    );
    if (!mounted) return;
    if (success) {
      await _loadCategories();
      setState(() {
        _editSelectedCategory = null;
        _editNewNameCtrl.clear();
        _hasUnsavedChanges = false;
      });
      _showSuccessDialog('Se han registrado los cambios en el inventario');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cambiar el nombre. Intente nuevamente.'),
          backgroundColor: AppTheme.cancelRed,
        ),
      );
    }
  }

  // ─── SECTION 2: AGREGAR ─────────────────────────────────────────────────────
  Widget _buildAgregarSection() {
    final isActive = _selectedSection == 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _selectedSection = isActive ? 0 : 2;
            _markChanged();
          }),
          child: Row(
            children: [
              Radio<int>(
                value: 2,
                groupValue: _selectedSection,
                onChanged: (v) => setState(() {
                  _selectedSection = v!;
                  _markChanged();
                }),
                activeColor: AppTheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const Text(
                'AGREGAR CATEGORÍA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (isActive) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _addNameCtrl,
            onChanged: (_) => _markChanged(),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: _ActionBtn(
              label: 'AGREGAR',
              color: AppTheme.primary,
              onTap: _onAgregarTap,
            ),
          ),
        ],
      ],
    );
  }

  void _onAgregarTap() {
    if (_addNameCtrl.text.trim().isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        icon: Icons.help_outline_rounded,
        iconColor: const Color(0xFFE6A817),
        message:
            '¿Seguro de agregar la categoría?\nRevise que no hayan categorías duplicadas',
        onYes: () {
          Navigator.pop(ctx);
          _doAgregarCategory();
        },
        onNo: () => Navigator.pop(ctx),
      ),
    );
  }

  Future<void> _doAgregarCategory() async {
    final newCat = _addNameCtrl.text.trim();
    if (_categories.contains(newCat)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta categoría ya existe.'),
          backgroundColor: AppTheme.cancelRed,
        ),
      );
      return;
    }
    final success = await SupabaseService.instance.addCategory(newCat);
    if (!mounted) return;
    if (success) {
      await _loadCategories();
      setState(() {
        _addNameCtrl.clear();
        _hasUnsavedChanges = false;
      });
      _showSuccessDialog(
        'Se han registrado las prendas nuevas en el inventario',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al agregar la categoría. Intente nuevamente.'),
          backgroundColor: AppTheme.cancelRed,
        ),
      );
    }
  }

  // ─── SECTION 3: OCULTAR ─────────────────────────────────────────────────────
  Widget _buildOcultarSection() {
    final isActive = _selectedSection == 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _selectedSection = isActive ? 0 : 3;
            _markChanged();
          }),
          child: Row(
            children: [
              Radio<int>(
                value: 3,
                groupValue: _selectedSection,
                onChanged: (v) => setState(() {
                  _selectedSection = v!;
                  _markChanged();
                }),
                activeColor: AppTheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const Text(
                'OCULTAR CATEGORÍA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (isActive) ...[
          const SizedBox(height: 8),
          _buildDropdown(
            value: _ocultarSelectedCategory,
            hint: '',
            items: _categories,
            onChanged: (v) => setState(() {
              _ocultarSelectedCategory = v;
              _markChanged();
            }),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: _ActionBtn(
              label: 'OCULTAR',
              color: AppTheme.primary,
              onTap: _onOcultarTap,
            ),
          ),
        ],
      ],
    );
  }

  void _onOcultarTap() {
    if (_ocultarSelectedCategory == null) return;
    showDialog(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        icon: Icons.help_outline_rounded,
        iconColor: const Color(0xFFE6A817),
        message:
            '¿Seguro que desea ocultar esta categoría?\nNo aparecerá en los listados',
        onYes: () {
          Navigator.pop(ctx);
          _doOcultarCategory();
        },
        onNo: () => Navigator.pop(ctx),
      ),
    );
  }

  Future<void> _doOcultarCategory() async {
    final success = await SupabaseService.instance.hideCategory(
      _ocultarSelectedCategory!,
    );
    if (!mounted) return;
    if (success) {
      await _loadCategories();
      setState(() {
        _ocultarSelectedCategory = null;
        _hasUnsavedChanges = false;
      });
      _showSuccessDialog('Se han registrado los cambios en el inventario');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al ocultar la categoría. Intente nuevamente.'),
          backgroundColor: AppTheme.cancelRed,
        ),
      );
    }
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────
  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCCCCCC), width: 1),
        borderRadius: BorderRadius.circular(6),
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: (value != null && items.contains(value)) ? value : null,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppTheme.textSecondary,
          ),
          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          items: items
              .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: AppTheme.primary,
                size: 52,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
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
                  ),
                  child: const Text(
                    'OK',
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
      ),
    );
  }
}

// ─── REUSABLE WIDGETS ────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String message;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const _ConfirmDialog({
    required this.icon,
    required this.iconColor,
    required this.message,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onYes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cancelRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'SI',
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
                    onPressed: onNo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
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
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
