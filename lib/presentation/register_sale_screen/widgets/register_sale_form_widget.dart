import '../../../core/app_export.dart';
import '../../../services/supabase_service.dart';

class RegisterSaleFormWidget extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  const RegisterSaleFormWidget({
    super.key,
    required this.product,
    required this.onCancel,
    required this.onSaved,
  });

  @override
  State<RegisterSaleFormWidget> createState() => _RegisterSaleFormWidgetState();
}

class _RegisterSaleFormWidgetState extends State<RegisterSaleFormWidget> {
  int _quantity = 1;
  String _paymentMethod = 'EFECTIVO';
  bool _isSaving = false;
  late TextEditingController _quantityController;
  late TextEditingController _totalPriceController;

  int get _maxQty =>
      (widget.product['stock'] as int?) ??
      (widget.product['quantity'] as int?) ??
      0;

  double get _purchasePrice =>
      ((widget.product['purchase_price'] as num?) ??
              (widget.product['costPrice'] as num?) ??
              0)
          .toDouble();

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
    _totalPriceController = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _totalPriceController.dispose();
    super.dispose();
  }

  void _increment() {
    setState(() {
      _quantity++;
      _quantityController.text = '$_quantity';
    });
  }

  void _decrement() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
        _quantityController.text = '$_quantity';
      });
    }
  }

  void _onQuantityTyped(String val) {
    final parsed = int.tryParse(val);
    if (parsed != null && parsed >= 1) {
      setState(() {
        _quantity = parsed;
      });
    } else if (val.isEmpty) {
      setState(() {
        _quantity = 0;
      });
    }
  }

  Future<void> _onSave() async {
    if (_quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La cantidad debe ser mayor a 0'),
          backgroundColor: AppTheme.cancelRed,
        ),
      );
      return;
    }

    if (_quantity > _maxQty) {
      _showValidationError();
      return;
    }

    final totalPriceText = _totalPriceController.text.trim();
    if (totalPriceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese el precio de venta total'),
          backgroundColor: AppTheme.cancelRed,
        ),
      );
      return;
    }

    final totalSalePrice = double.tryParse(totalPriceText) ?? 0;
    if (totalSalePrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El precio de venta debe ser mayor a 0'),
          backgroundColor: AppTheme.cancelRed,
        ),
      );
      return;
    }

    final salePrice = _quantity > 0 ? totalSalePrice / _quantity : 0.0;

    setState(() => _isSaving = true);

    final productId = widget.product['id']?.toString() ?? '';
    final productName = (widget.product['name'] as String?) ?? '';
    final productCategory = (widget.product['category'] as String?) ?? '';

    if (productId.isEmpty) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: producto no válido. Intente nuevamente.'),
            backgroundColor: AppTheme.cancelRed,
          ),
        );
      }
      return;
    }

    final success = await SupabaseService.instance.registerSale(
      productId: productId,
      productName: productName,
      productCategory: productCategory,
      quantity: _quantity,
      salePrice: salePrice,
      costPrice: _purchasePrice,
      paymentMethod: _paymentMethod,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        _showSuccessDialog();
      } else {
        // Could be insufficient stock (validated server-side) or network error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _quantity > _maxQty
                  ? 'Stock insuficiente. Solo hay $_maxQty unidades disponibles.'
                  : 'Error al registrar la venta. Intente nuevamente.',
            ),
            backgroundColor: AppTheme.cancelRed,
          ),
        );
      }
    }
  }

  void _showValidationError() {
    showDialog(
      context: context,
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
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: AppTheme.cancelRed,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'La cantidad de venta excede la cantidad actual',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
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
                    backgroundColor: AppTheme.cancelRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
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
    final String productName = (widget.product['name'] as String?) ?? '';
    final String productCategory =
        (widget.product['category'] as String?) ?? '';
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
            'REGISTRAR VENTAS',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Product image
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isNotEmpty
                  ? CustomImageWidget(
                      imageUrl: imageUrl,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                      semanticLabel: semanticLabel,
                    )
                  : Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.checkroom_rounded,
                        color: AppTheme.primary,
                        size: 60,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Nombre del Producto
          const Text(
            'Nombre del Producto',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCCCCCC), width: 1),
            ),
            child: Text(
              productName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Talla (read-only)
          Builder(
            builder: (ctx) {
              final String? size = widget.product['size'] as String?;
              if (size == null || size.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Talla',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFCCCCCC),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      size,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              );
            },
          ),

          // Categoría (read-only)
          const Text(
            'Categoría',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCCCCCC), width: 1),
            ),
            child: Text(
              productCategory,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
          ),
          const SizedBox(height: 14),

          // Cant. Actual
          const Text(
            'Cant. Actual',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCCCCCC), width: 1),
            ),
            child: Text(
              '$_maxQty und.',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Cantidad Vendida
          const Text(
            'Cantidad Vendida',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _QBtn(
                  icon: Icons.remove_rounded,
                  onTap: _decrement,
                  enabled: _quantity > 1,
                ),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: _onQuantityTyped,
                        style: const TextStyle(
                          fontSize: 20,
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
                _QBtn(
                  icon: Icons.add_rounded,
                  onTap: _increment,
                  enabled: true,
                ),
              ],
            ),
          ),
          if (_quantity > _maxQty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Excede la cantidad disponible ($_maxQty und.)',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.cancelRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 14),

          // Precio de Venta Total
          const Text(
            'Precio de Venta Total',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                const Text(
                  'S/ ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _totalPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Payment method
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = 'EFECTIVO'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _paymentMethod == 'EFECTIVO'
                          ? AppTheme.primary
                          : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _paymentMethod == 'EFECTIVO'
                            ? AppTheme.primaryDark
                            : const Color(0xFFCCCCCC),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'EFECTIVO',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _paymentMethod == 'EFECTIVO'
                              ? Colors.white
                              : AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = 'VIRTUAL'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _paymentMethod == 'VIRTUAL'
                          ? AppTheme.primary
                          : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _paymentMethod == 'VIRTUAL'
                            ? AppTheme.primaryDark
                            : const Color(0xFFCCCCCC),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'VIRTUAL',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _paymentMethod == 'VIRTUAL'
                              ? Colors.white
                              : AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // CANCELAR / GUARDAR
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : widget.onCancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cancelRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: const Text(
                    'CANCELAR',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
                    padding: const EdgeInsets.symmetric(vertical: 18),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
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
          width: 58,
          height: 38,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppTheme.primaryDark : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
