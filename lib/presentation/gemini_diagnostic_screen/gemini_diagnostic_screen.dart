import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/aiIntegrations/chat_completion_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation_drawer.dart';
import '../../routes/app_routes.dart';

enum _TestStatus { idle, running, success, error }

class GeminiDiagnosticScreen extends StatefulWidget {
  const GeminiDiagnosticScreen({super.key});

  @override
  State<GeminiDiagnosticScreen> createState() => _GeminiDiagnosticScreenState();
}

class _GeminiDiagnosticScreenState extends State<GeminiDiagnosticScreen> {
  _TestStatus _status = _TestStatus.idle;
  String _statusMessage = '';
  String _rawResponse = '';
  String _extractedContent = '';
  String _errorDetail = '';
  Duration? _elapsed;

  static const _lambdaUrl = String.fromEnvironment(
    'AWS_LAMBDA_CHAT_COMPLETION_URL',
  );

  Future<void> _runTest() async {
    setState(() {
      _status = _TestStatus.running;
      _statusMessage = 'Enviando solicitud a Lambda…';
      _rawResponse = '';
      _extractedContent = '';
      _errorDetail = '';
      _elapsed = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      final response = await getChatCompletion(
        'GEMINI',
        'gemini/gemini-3.6-flash',
        [
          {'role': 'user', 'content': 'Responde únicamente con la palabra: OK'},
        ],
        // reasoning_effort omitted — the deployed Lambda may not have
        // drop_params, and gemini-3.6-flash 400s on unsupported params.
        // max_tokens leaves headroom for default thinking-token usage.
        parameters: {'max_tokens': 100},
      );

      stopwatch.stop();
      final elapsed = stopwatch.elapsed;

      // Pretty-print the raw response
      final pretty = const JsonEncoder.withIndent('  ').convert(response);

      // Check for error body
      if (response.containsKey('error')) {
        final errorMsg = response['error']?.toString() ?? 'Error desconocido';
        final details = response['details']?.toString() ?? '';
        setState(() {
          _status = _TestStatus.error;
          _elapsed = elapsed;
          _statusMessage = '❌ Lambda respondió con error en el body';
          _errorDetail =
              '$errorMsg${details.isNotEmpty ? '\n\nDetalles: $details' : ''}';
          _rawResponse = pretty;
        });
        return;
      }

      // Extract content
      String content = '';
      final choices = response['choices'];
      if (choices is List && choices.isNotEmpty) {
        final msg = choices[0]?['message'];
        final raw = msg?['content'];
        if (raw is String) content = raw;
      }

      setState(() {
        _status = _TestStatus.success;
        _elapsed = elapsed;
        _statusMessage = '✅ API Key válida — Gemini respondió correctamente';
        _extractedContent = content.isNotEmpty
            ? content
            : '(sin contenido extraído)';
        _rawResponse = pretty;
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _status = _TestStatus.error;
        _elapsed = stopwatch.elapsed;
        _statusMessage = '❌ Error al llamar a Lambda';
        _errorDetail = e.toString();
        _rawResponse = '';
      });
    }
  }

  Color get _statusColor {
    switch (_status) {
      case _TestStatus.success:
        return const Color(0xFF22C55E);
      case _TestStatus.error:
        return AppTheme.cancelRed;
      case _TestStatus.running:
        return AppTheme.primary;
      case _TestStatus.idle:
        return const Color(0xFF888888);
    }
  }

  IconData get _statusIcon {
    switch (_status) {
      case _TestStatus.success:
        return Icons.check_circle_rounded;
      case _TestStatus.error:
        return Icons.error_rounded;
      case _TestStatus.running:
        return Icons.hourglass_top_rounded;
      case _TestStatus.idle:
        return Icons.science_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        title: const Text(
          'Diagnóstico Gemini',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppNavigationDrawer(
        activeRoute: AppRoutes.geminiDiagnosticScreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Prueba de conectividad',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Esta prueba envía una solicitud real a la Lambda de Gemini '
                    'y verifica si la API Key está configurada correctamente en el servidor.',
                    style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Proveedor', value: 'GEMINI'),
                  _InfoRow(label: 'Modelo', value: 'gemini/gemini-3.6-flash'),
                  _InfoRow(
                    label: 'Lambda URL',
                    value: _lambdaUrl.isNotEmpty
                        ? '${_lambdaUrl.substring(0, _lambdaUrl.length.clamp(0, 40))}…'
                        : '⚠️ NO CONFIGURADA',
                    valueColor: _lambdaUrl.isEmpty ? AppTheme.cancelRed : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Run button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _status == _TestStatus.running ? null : _runTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  disabledBackgroundColor: AppTheme.primary.withAlpha(100),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _status == _TestStatus.running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, color: Colors.white),
                label: Text(
                  _status == _TestStatus.running
                      ? 'Ejecutando prueba…'
                      : 'Ejecutar prueba de API Key',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

            if (_status != _TestStatus.idle) ...[
              const SizedBox(height: 24),

              // Status card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _statusColor.withAlpha(100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _status == _TestStatus.running
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _statusColor,
                                ),
                              )
                            : Icon(_statusIcon, color: _statusColor, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: TextStyle(
                              color: _statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_elapsed != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Tiempo de respuesta: ${_elapsed!.inMilliseconds} ms',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Error detail
              if (_errorDetail.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Detalle del error',
                  titleColor: AppTheme.cancelRed,
                  icon: Icons.bug_report_rounded,
                  child: SelectableText(
                    _errorDetail,
                    style: const TextStyle(
                      color: Color(0xFFFF8A80),
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],

              // Extracted content
              if (_extractedContent.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Contenido extraído de la respuesta',
                  titleColor: const Color(0xFF22C55E),
                  icon: Icons.text_snippet_rounded,
                  child: SelectableText(
                    _extractedContent,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],

              // Raw response
              if (_rawResponse.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Respuesta completa de Lambda',
                  titleColor: const Color(0xFF888888),
                  icon: Icons.code_rounded,
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: Color(0xFF888888),
                      size: 18,
                    ),
                    tooltip: 'Copiar JSON',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _rawResponse));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('JSON copiado al portapapeles'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  child: SelectableText(
                    _rawResponse,
                    style: const TextStyle(
                      color: Color(0xFFCCCCCC),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],

              // Diagnosis tips
              if (_status == _TestStatus.error) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Posibles causas y soluciones',
                  titleColor: const Color(0xFFFFA726),
                  icon: Icons.lightbulb_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _TipRow(
                        number: '1',
                        text:
                            'La variable GEMINI_API_KEY no está configurada en la Lambda. '
                            'Verifica las variables de entorno en AWS Lambda.',
                      ),
                      SizedBox(height: 8),
                      _TipRow(
                        number: '2',
                        text:
                            'La API Key es inválida o fue revocada. '
                            'Genera una nueva en Google AI Studio y actualízala en la Lambda.',
                      ),
                      SizedBox(height: 8),
                      _TipRow(
                        number: '3',
                        text:
                            'La Lambda URL no está configurada en env.json '
                            '(AWS_LAMBDA_CHAT_COMPLETION_URL vacío).',
                      ),
                      SizedBox(height: 8),
                      _TipRow(
                        number: '4',
                        text:
                            'El modelo gemini/gemini-3.6-flash no está disponible '
                            'para tu API Key. Verifica los permisos en Google AI Studio.',
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? const Color(0xFFCCCCCC),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Color titleColor;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.titleColor,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: titleColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final String number;
  final String text;

  const _TipRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFFFA726).withAlpha(50),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFFFFA726),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
          ),
        ),
      ],
    );
  }
}