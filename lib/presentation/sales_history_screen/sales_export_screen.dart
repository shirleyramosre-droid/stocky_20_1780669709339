import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import '../../utils/sales_aggregation.dart';

/// Lets the user pick a date range, review aggregated sold products and
/// download a PDF with the selected ones.
class SalesExportScreen extends StatefulWidget {
  const SalesExportScreen({super.key});

  @override
  State<SalesExportScreen> createState() => _SalesExportScreenState();
}

class _SalesExportScreenState extends State<SalesExportScreen> {
  DateTimeRange? _range;
  List<SoldProduct> _products = [];
  final Set<String> _selected = {};
  bool _isLoading = false;
  bool _isGenerating = false;

  String _fmt(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  String get _rangeLabel =>
      _range == null ? '' : '${_fmt(_range!.start)} - ${_fmt(_range!.end)}';

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range,
      helpText: 'Seleccione el rango de fechas',
      saveText: 'Aceptar',
    );
    if (picked == null) return;
    setState(() {
      _range = picked;
      _isLoading = true;
    });
    final sales = await SupabaseService.instance.getAllSales();
    if (!mounted) return;
    final products = aggregateSalesByName(sales, picked.start, picked.end);
    setState(() {
      _products = products;
      _selected
        ..clear()
        ..addAll(products.map((p) => p.name));
      _isLoading = false;
    });
  }

  bool get _allSelected =>
      _products.isNotEmpty && _selected.length == _products.length;

  void _toggleAll(bool? value) {
    setState(() {
      _selected.clear();
      if (value == true) _selected.addAll(_products.map((p) => p.name));
    });
  }

  Future<void> _download() async {
    final chosen = _products.where((p) => _selected.contains(p.name)).toList();
    if (chosen.isEmpty || _range == null) return;
    setState(() => _isGenerating = true);
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => [
            pw.Text(
              'Productos vendidos: $_rangeLabel',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['Producto', 'Cantidad'],
              data: chosen.map((p) => [p.name, '${p.quantity}']).toList(),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
              },
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );
      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'ventas_${_range!.start.millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      debugPrint('[SalesExport] PDF error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo generar el PDF.'),
            backgroundColor: AppTheme.cancelRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Descargar lista'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_rounded),
                label: Text(
                  _range == null ? 'Seleccionar rango de fechas' : _rangeLabel,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildList()),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: (_selected.isEmpty || _isGenerating)
                    ? null
                    : _download,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Descargar seleccionados',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_range == null) {
      return const Center(
        child: Text(
          'Elija un rango de fechas para ver los productos vendidos.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }
    if (_products.isEmpty) {
      return const Center(
        child: Text(
          'No hay ventas en este rango.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }
    return Column(
      children: [
        CheckboxListTile(
          value: _allSelected,
          onChanged: _toggleAll,
          title: const Text(
            'Seleccionar todos',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppTheme.primary,
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _products.length,
            itemBuilder: (_, i) {
              final p = _products[i];
              return CheckboxListTile(
                value: _selected.contains(p.name),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(p.name);
                  } else {
                    _selected.remove(p.name);
                  }
                }),
                title: Text(p.name),
                secondary: Text(
                  '${p.quantity} und.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppTheme.primary,
              );
            },
          ),
        ),
      ],
    );
  }
}
