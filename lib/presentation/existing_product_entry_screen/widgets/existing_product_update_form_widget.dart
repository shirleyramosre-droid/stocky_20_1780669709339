import 'package:flutter/services.dart';

import '../../../core/app_export.dart';
import '../../../services/supabase_service.dart';

class ExistingProductUpdateFormWidget extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  const ExistingProductUpdateFormWidget({
    super.key,
    required this.product,
    required this.onCancel,
    required this.onSaved,
  });

  @override
  State<ExistingProductUpdateFormWidget> createState() =>
      _ExistingProductUpdateFormWidgetState();
}

class _ExistingProductUpdateFormWidgetState
    extends State<ExistingProductUpdateFormWidget> {
  final _priceController = TextEditingController();
  late TextEditingController _additionalQtyController;
  int _additionalQuantity = 1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _additionalQtyController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _priceController.dispose();
    _additionalQtyController.dispose();
    super.dispose();
  }

  void _increment() {
    setState(() {
      _additionalQuantity++;
      _additionalQtyController.text = '$_additionalQuantity';
    });
  }

  void _decrement() {
    if (_additionalQuantity > 1) {
      setState(() {
        _additionalQuantity--;
        _additionalQtyController.text = '$_additionalQuantity';
      });
    }
  }

  void _onQtyTyped(String val) {
    final parsed = int.tryParse(val);
    if (parsed != null && parsed >= 1) {
      setState(() => _additionalQuantity = parsed);
    }
  }

  Future<void> _onCancel() async {
    final confirm = await _showConfirmDialog();
    if (confirm == true && mounted) widget.onCancel();
  }

  Future<void> _onSave() async {
    if (_priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese el precio de compra actual.'),
          backgroundColor: AppTheme.cancelRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final totalPrice = double.tryParse(_priceController.text.trim()) ?? 0;
    // New unit price = precio de compra actual / cantidad adicional
    final newUnitPrice = _additionalQuantity > 0
        ? totalPrice / _additionalQuantity
        : totalPrice;
    final productId = widget.product['id']?.toString() ?? '';

    bool success = false;
    if (productId.isNotEmpty) {
      success = await SupabaseService.instance.updateProductStock(
        productId,
        _additionalQuantity,
        newUnitPrice,
      );
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar. Intente nuevamente.'),
            backgroundColor: AppTheme.cancelRed,
          ),
        );
      }
    }
  }

  Future<bool?> _showConfirmDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF9C4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.help_rounded,
                  color: Color(0xFFF9A825),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '¿Seguro que desea salir?\nSi lo hace perderá todo su progreso',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                      ),
                      child: const Text(
                        'SÍ',
                        style: TextStyle(fontWeight: FontWeight.w700),
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
                      ),
                      child: const Text(
                        'NO',
                        style: TextStyle(fontWeight: FontWeight.w700),
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.success,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Se han registrado las prendas nuevas en el inventario',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onSaved();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'ACEPTAR',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int currentQty =
        (widget.product['stock'] as int?) ??
        (widget.product['quantity'] as int?) ??
        0;
    final String imageUrl =
        (widget.product['image_url'] as String?) ??
        (widget.product['imageUrl'] as String?) ??
        '';
    final String semanticLabel =
        (widget.product['semanticLabel'] as String?) ?? 'Imagen del producto';

    return SingleChildScrollView(
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

          // Product image preview
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primary.withAlpha(102),
                width: 2,
              ),
              color: AppTheme.primaryContainer,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl.isNotEmpty
                  ? CustomImageWidget(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.contain,
                      semanticLabel: semanticLabel,
                    )
                  : const Icon(
                      Icons.checkroom_rounded,
                      size: 60,
                      color: AppTheme.primary,
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // Product name (read-only)
          _FieldLabel('Nombre del Producto'),
          const SizedBox(height: 6),
          _ReadOnlyField((widget.product['name'] as String?) ?? ''),

          const SizedBox(height: 14),

          // Talla (read-only, only if present)
          Builder(
            builder: (ctx) {
              final String? size = widget.product['size'] as String?;
              if (size == null || size.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Talla'),
                  const SizedBox(height: 6),
                  _ReadOnlyField(size),
                  const SizedBox(height: 14),
                ],
              );
            },
          ),

          // Category (read-only)
          _FieldLabel('Categoría'),
          const SizedBox(height: 6),
          _ReadOnlyField((widget.product['category'] as String?) ?? ''),

          const SizedBox(height: 14),

          // Quantity row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Cant. Actual'),
                    const SizedBox(height: 6),
                    _ReadOnlyField('$currentQty und.'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Cantidad Adicional'),
                    const SizedBox(height: 6),
                    _buildQuantitySelector(),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Price
          _FieldLabel('Precio de Compra Actual'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              prefixText: 'S/ ',
              prefixStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              hintText: '0.00',
            ),
          ),

          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onCancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cancelRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'CANCELAR',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'GUARDAR',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _QBtn(
            icon: Icons.remove_rounded,
            onTap: _decrement,
            enabled: _additionalQuantity > 1,
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 60,
                child: TextField(
                  controller: _additionalQtyController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: _onQtyTyped,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
          _QBtn(icon: Icons.add_rounded, onTap: _increment, enabled: true),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String value;
  const _ReadOnlyField(this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _QBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _QBtn({required this.icon, required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppTheme.primaryContainer : const Color(0xFFF0F0F0),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppTheme.primaryDark : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
