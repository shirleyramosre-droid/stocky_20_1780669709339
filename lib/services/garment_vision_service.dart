import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/services/aiIntegrations/chat_completion_service.dart';
import '../services/supabase_service.dart';

/// Result of a garment vision comparison.
class GarmentMatch {
  final Map<String, dynamic> product;
  final double confidence;
  final String reason;

  const GarmentMatch({
    required this.product,
    required this.confidence,
    required this.reason,
  });
}

/// Shared vision service for Stocky.
///
/// Group 1 – "Ingreso de Prendas Nuevas":
///   Call [extractTagsFromImage] to get a semicolon-separated tag string
///   to be saved in ai_tags.
///
/// Group 2 – "Ingreso de Prendas Existentes", "Registrar Venta", "Catálogo":
///   Call [findTopMatches] to analyse a photo, extract tags, then filter
///   the catalog using a contains query on ai_tags and return the 3 products
///   with the most tag matches. Photos are NEVER saved.
class GarmentVisionService {
  GarmentVisionService._();
  static final GarmentVisionService instance = GarmentVisionService._();

  // ─── Shared prompt ──────────────────────────────────────────────────────────

  static const String _systemPrompt =
      'Eres un experto en análisis visual de productos de moda y textiles. '
      'Analiza el artículo de la imagen y extrae sus características visuales. '
      'Principalmente será ropa, pero también puede ser calzado, accesorios o textiles para el hogar.\n\n'
      'Devuelve ÚNICAMENTE un objeto JSON válido con la siguiente estructura, '
      'sin saludos, ni explicaciones, ni texto adicional antes o después del JSON:\n\n'
      '{\n'
      '  "categoria_general": "ej. ropa, ropa_interior, calzado, accesorios, textil_hogar",\n'
      '  "tipo_especifico": "ej. camisa, pantalon, medias, zapatillas, manta",\n'
      '  "publico_objetivo": "ej. hombre, mujer, ninos, bebes, unisex, hogar",\n'
      '  "estilo_u_ocasion": "ej. casual, formal, deportivo, escolar, pijama",\n'
      '  "corte_o_silueta": "ej. ajustado, holgado, recto, acampanado",\n'
      '  "longitud": "ej. manga corta, manga larga, pantalon corto, no aplica",\n'
      '  "patron_o_diseno": "ej. liso, rayas, cuadros, estampado grafico",\n'
      '  "textura_o_acabado": "ej. suave, acanalado, rasgado, brillante, tejido grueso",\n'
      '  "marca_o_texto_visible": "ej. logo de cocodrilo, texto impreso, sin marca visible",\n'
      '  "detalles_especificos": "ej. cuello V, capucha, botones delanteros, pasadores, cierre"\n'
      '}';

  // ─── GROUP 1: Extract tags for new product ──────────────────────────────────

  /// Sends [imageBytes] to Gemini and returns a semicolon-separated string
  /// of all values from the JSON response (e.g. "ropa;chompa;mujer;acanalado").
  /// Returns null on error.
  Future<String?> extractTagsFromImage(Uint8List imageBytes) async {
    debugPrint('[AI_TAGS] ══════════════════════════════════════════');
    debugPrint('[AI_TAGS] Iniciando análisis de imagen con Gemini...');
    debugPrint('[AI_TAGS] Tamaño de imagen: ${imageBytes.length} bytes');

    try {
      final base64Image = base64Encode(imageBytes);
      debugPrint('[AI_TAGS] Imagen codificada en base64 correctamente');
      debugPrint('[AI_TAGS] Enviando imagen a Gemini...');

      final response = await getChatCompletion(
        'GEMINI',
        'gemini/gemini-3.6-flash',
        [
          {'role': 'system', 'content': _systemPrompt},
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text':
                    'Analiza esta imagen y devuelve el JSON con las características del artículo.',
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
              },
            ],
          },
        ],
        parameters: {
          'max_tokens': 1500,
          'temperature': 0.1,
          // gemini-3.6-flash always reasons — thinking can't be fully
          // disabled, only dialed down — and thinking tokens share the same
          // max_tokens budget as the visible output. 'minimal' keeps that
          // consumption as low as possible; max_tokens was raised from 800
          // to leave headroom for whatever minimal thinking still uses.
          'reasoning_effort': 'minimal',
        },
      );

      debugPrint('[AI_TAGS] Gemini response keys: ${response.keys.toList()}');

      // ── Detect error body regardless of HTTP status ──────────────────────
      if (response.containsKey('error')) {
        final errorMsg = response['error']?.toString() ?? 'Unknown error';
        final details = response['details']?.toString() ?? '';
        debugPrint('[AI_TAGS] ERROR - Gemini API error: $errorMsg — $details');
        throw Exception('$errorMsg${details.isNotEmpty ? ': $details' : ''}');
      }

      // Extract the text content — handle multiple response formats
      String content = _extractContentFromResponse(response);

      debugPrint('[AI_TAGS] Gemini response: $content');

      if (content.isEmpty) {
        debugPrint('[AI_TAGS] ERROR - Gemini devolvió contenido vacío');
        return null;
      }

      final tags = _jsonToTagString(content);
      debugPrint('[AI_TAGS] Tags generados: $tags');
      return tags;
    } catch (e) {
      debugPrint('[AI_TAGS] ERROR en extractTagsFromImage: $e');
      rethrow;
    }
  }

  // ─── GROUP 2: Find top matches using ai_tags contains filter ───────────────

  /// Analyses [imageBytes], extracts tags, then queries Supabase for products
  /// whose ai_tags column contains those tags (contains filter).
  /// Returns up to 3 products ordered by number of matching tags (descending).
  /// Photos are NEVER saved.
  Future<List<GarmentMatch>> findTopMatches(Uint8List imageBytes) async {
    debugPrint('[IMAGE_SEARCH] ══════════════════════════════════════════');
    debugPrint('[IMAGE_SEARCH] Imagen recibida (${imageBytes.length} bytes)');

    try {
      // Step 1: Extract tags from the search photo
      String? tagsString;
      try {
        tagsString = await extractTagsFromImage(imageBytes);
      } catch (geminiError) {
        debugPrint('[IMAGE_SEARCH] ERROR A - Gemini falló: $geminiError');
        return [];
      }

      if (tagsString == null || tagsString.isEmpty) {
        debugPrint(
          '[IMAGE_SEARCH] ERROR B - Gemini respondió pero no pudo identificar el producto',
        );
        return _fallbackMatches();
      }

      debugPrint('[IMAGE_SEARCH] Datos extraídos de Gemini: $tagsString');

      final searchTags = tagsString
          .split(';')
          .map((t) => _normalize(t.trim()))
          .where((t) => t.isNotEmpty && t != 'null' && t.length > 2)
          .toList();

      debugPrint(
        '[IMAGE_SEARCH] Search criteria (tags normalizados): $searchTags',
      );

      if (searchTags.isEmpty) {
        debugPrint(
          '[IMAGE_SEARCH] ERROR B - No se pudieron extraer tags válidos',
        );
        return _fallbackMatches();
      }

      // Step 2: Get all products from local cache
      final allProducts = await SupabaseService.instance.getProducts();
      debugPrint(
        '[IMAGE_SEARCH] Total productos en catálogo: ${allProducts.length}',
      );

      if (allProducts.isEmpty) {
        debugPrint(
          '[IMAGE_SEARCH] ERROR D - No hay productos en el catálogo local',
        );
        return [];
      }

      // Step 3: Score each product
      final scored = <_ScoredProduct>[];
      int productsWithTags = 0;
      int productsWithoutTags = 0;

      for (final product in allProducts) {
        final aiTagsRaw = (product['ai_tags'] as String?) ?? '';
        final productName = _normalize((product['name'] as String?) ?? '');
        final productCategory = _normalize(
          (product['category'] as String?) ?? '',
        );
        final productSize = _normalize((product['size'] as String?) ?? '');

        int matchCount = 0;

        if (aiTagsRaw.isNotEmpty) {
          productsWithTags++;
          // Score by ai_tags
          final aiTagsNorm = _normalize(aiTagsRaw);
          for (final tag in searchTags) {
            if (aiTagsNorm.contains(tag)) matchCount += 2; // ai_tags worth more
          }
        } else {
          productsWithoutTags++;
        }

        // Also score by name, category, size (tolerant fallback for products without ai_tags)
        for (final tag in searchTags) {
          if (productName.contains(tag)) matchCount += 1;
          if (productCategory.contains(tag)) matchCount += 1;
          if (productSize.isNotEmpty && productSize.contains(tag)) {
            matchCount += 1;
          }
        }

        if (matchCount > 0) {
          scored.add(_ScoredProduct(product: product, score: matchCount));
        }
      }

      debugPrint(
        '[IMAGE_SEARCH] Productos con ai_tags: $productsWithTags, sin ai_tags: $productsWithoutTags',
      );
      debugPrint(
        '[IMAGE_SEARCH] Productos con coincidencias: ${scored.length}',
      );

      // Step 4: Sort by score descending, take top 3
      scored.sort((a, b) => b.score.compareTo(a.score));
      final top3 = scored.take(3).toList();

      debugPrint(
        '[IMAGE_SEARCH] Supabase query: búsqueda local por ai_tags + name + category',
      );
      debugPrint('[IMAGE_SEARCH] Results count: ${top3.length}');

      if (top3.isNotEmpty) {
        for (final s in top3) {
          final name = s.product['name'] ?? 'sin nombre';
          final tags = s.product['ai_tags'] ?? 'sin tags';
          debugPrint(
            '[IMAGE_SEARCH]   → "$name" (score: ${s.score}) | ai_tags: "$tags"',
          );
        }
      }

      if (top3.isEmpty) {
        debugPrint(
          '[IMAGE_SEARCH] ERROR E - Consulta válida pero devolvió 0 resultados. '
          'Verificar que los productos tengan ai_tags o que los nombres coincidan con: $searchTags',
        );
        // Fall back to returning top products by stock
        return _fallbackMatches();
      }

      return top3.map((s) {
        final maxPossibleScore = searchTags.length * 2;
        final confidence = maxPossibleScore > 0
            ? (s.score / maxPossibleScore).clamp(0.0, 1.0)
            : 0.0;
        return GarmentMatch(
          product: s.product,
          confidence: confidence,
          reason:
              '${s.score} coincidencia${s.score != 1 ? 's' : ''} de etiquetas',
        );
      }).toList();
    } catch (e) {
      debugPrint('[IMAGE_SEARCH] ERROR inesperado en findTopMatches: $e');
      return [];
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Extracts text content from Gemini response regardless of format.
  String _extractContentFromResponse(Map<String, dynamic> response) {
    String content = '';

    // Format 1: OpenAI-style choices array (most common via Lambda)
    final choices = response['choices'];
    if (choices is List && choices.isNotEmpty) {
      final message = choices[0]?['message'];
      final rawContent = message?['content'];
      if (rawContent is String && rawContent.isNotEmpty) {
        content = rawContent;
      } else if (rawContent is List) {
        for (final part in rawContent) {
          if (part is Map) {
            final text = part['text'] ?? part['content'] ?? '';
            if (text is String && text.isNotEmpty) {
              content = text;
              break;
            }
          }
        }
      }
    }

    // Format 2: Gemini native candidates array
    if (content.isEmpty) {
      final candidates = response['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final parts = candidates[0]?['content']?['parts'];
        if (parts is List && parts.isNotEmpty) {
          final text = parts[0]?['text'];
          if (text is String && text.isNotEmpty) {
            content = text;
          }
        }
      }
    }

    // Format 3: Direct text/content/result field at root level
    if (content.isEmpty) {
      final directText =
          response['text'] ?? response['content'] ?? response['result'];
      if (directText is String && directText.isNotEmpty) {
        content = directText;
      }
    }

    // Format 4: output field (some SDK versions)
    if (content.isEmpty) {
      final output = response['output'];
      if (output is String && output.isNotEmpty) {
        content = output;
      }
    }

    return content;
  }

  /// Normalizes a string: lowercase + remove accents + trim.
  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('à', 'a')
        .replaceAll('è', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ù', 'u')
        .trim();
  }

  /// Parses the Gemini JSON response and returns all values joined by "; ".
  /// List values (e.g. detalles_especificos array) are expanded item by item.
  /// Size/talla values are excluded.
  String? _jsonToTagString(String content) {
    try {
      String jsonStr = content.trim();

      // Strip markdown code fences if present (```json ... ``` or ``` ... ```)
      final start = jsonStr.indexOf('{');
      final end = jsonStr.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        jsonStr = jsonStr.substring(start, end + 1);
      }

      if (jsonStr.isEmpty) {
        debugPrint('[AI_TAGS] No se encontró objeto JSON en el contenido');
        return null;
      }

      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      debugPrint('[AI_TAGS] JSON parseado de Gemini: $parsed');

      // Regex to detect size/talla values to exclude
      final sizePattern = RegExp(
        r'^(talla\s*\w+|xs|s|m|l|xl|xxl|xxxl|\d+)$',
        caseSensitive: false,
      );

      // Generic/useless tags to exclude
      final uselessTags = <String>{
        'producto',
        'objeto',
        'cosa',
        'foto',
        'imagen',
        'no aplica',
        'null',
        'n/a',
        'desconocido',
        'unknown',
      };

      final tags = <String>[];

      for (final entry in parsed.entries) {
        final raw = entry.value;
        if (raw == null) continue;

        // Collect raw string tokens from this field
        final tokens = <String>[];

        if (raw is List) {
          for (final item in raw) {
            final s = item?.toString().trim() ?? '';
            if (s.isNotEmpty) tokens.add(s);
          }
        } else {
          final s = raw.toString().trim();
          if (s.isNotEmpty) {
            tokens.addAll(
              s.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty),
            );
          }
        }

        // Add tokens that are not empty, not useless, and not a size value
        for (final token in tokens) {
          final tokenLower = token.toLowerCase().trim();
          if (tokenLower.isEmpty) continue;
          if (uselessTags.contains(tokenLower)) continue;
          if (sizePattern.hasMatch(tokenLower)) continue;
          // Avoid duplicates (case-insensitive)
          final normalized = _normalize(token);
          if (!tags.any((t) => _normalize(t) == normalized)) {
            tags.add(token);
          }
        }
      }

      if (tags.isEmpty) {
        debugPrint('[AI_TAGS] No se extrajeron tags del JSON');
        return null;
      }

      final result = tags.join('; ');
      debugPrint('[AI_TAGS] Tag string final: $result');
      return result;
    } catch (e) {
      debugPrint('[AI_TAGS] Error parseando JSON de Gemini: $e');
      return null;
    }
  }

  Future<List<GarmentMatch>> _fallbackMatches() async {
    debugPrint('[IMAGE_SEARCH] Usando fallback: top 3 productos por stock');
    try {
      final allProducts = await SupabaseService.instance.getProducts();
      // Sort by stock descending for fallback
      final sorted = List<Map<String, dynamic>>.from(allProducts)
        ..sort(
          (a, b) =>
              ((b['stock'] as int?) ?? 0).compareTo((a['stock'] as int?) ?? 0),
        );
      return sorted
          .take(3)
          .map(
            (p) => GarmentMatch(
              product: p,
              confidence: 0.0,
              reason: 'Sin etiquetas disponibles',
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class _ScoredProduct {
  final Map<String, dynamic> product;
  final int score;
  const _ScoredProduct({required this.product, required this.score});
}
