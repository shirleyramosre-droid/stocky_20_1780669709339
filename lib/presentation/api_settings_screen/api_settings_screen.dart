import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/gemini_api_key_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation_drawer.dart';

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _loading = true;
  bool _hasSavedKey = false;
  String? _feedback;
  Color _feedbackColor = AppTheme.success;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await GeminiApiKeyService.instance.getApiKey();
    if (!mounted) return;
    setState(() {
      _hasSavedKey = key != null;
      _controller.text = key ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() {
        _feedback = 'Escribe una API Key antes de guardar.';
        _feedbackColor = AppTheme.cancelRed;
      });
      return;
    }
    await GeminiApiKeyService.instance.setApiKey(value);
    if (!mounted) return;
    setState(() {
      _hasSavedKey = true;
      _feedback =
          '✅ Guardada. La app llamará a Gemini directamente con tu API Key.';
      _feedbackColor = AppTheme.success;
    });
  }

  Future<void> _clear() async {
    await GeminiApiKeyService.instance.clearApiKey();
    if (!mounted) return;
    setState(() {
      _controller.clear();
      _hasSavedKey = false;
      _feedback = 'Key eliminada. La app volverá a usar el servidor de Rocket.';
      _feedbackColor = AppTheme.textSecondary;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        title: const Text(
          'Configuración de API',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppNavigationDrawer(activeRoute: AppRoutes.apiSettingsScreen),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.vpn_key_rounded,
                              color: AppTheme.primaryDark,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tu API Key de Gemini',
                              style: TextStyle(
                                color: AppTheme.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Si registras aquí tu propia API Key de Google Gemini, la app '
                          'la llamará directamente (sin pasar por el servidor de Rocket). '
                          'Se guarda solo en este dispositivo. Si la dejas vacía, la app '
                          'sigue usando el servidor de Rocket como hasta ahora.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _controller,
                    obscureText: _obscure,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'API Key de Gemini',
                      hintText: 'AIza...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Consíguela gratis en Google AI Studio (aistudio.google.com).',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.save_rounded, color: Colors.white),
                          label: const Text(
                            'Guardar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (_hasSavedKey) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clear,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.cancelRed,
                              side: BorderSide(color: AppTheme.cancelRed),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text(
                              'Eliminar',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_feedback != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _feedback!,
                      style: TextStyle(color: _feedbackColor, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _hasSavedKey
                              ? Icons.cloud_off_rounded
                              : Icons.cloud_rounded,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _hasSavedKey
                                ? 'Modo activo: conexión directa con tu API Key.'
                                : 'Modo activo: servidor de Rocket (sin key personal).',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.geminiDiagnosticScreen,
                    ),
                    icon: const Icon(Icons.biotech_rounded),
                    label: const Text('Ir a Diagnóstico Gemini para probarla'),
                  ),
                ],
              ),
            ),
    );
  }
}
