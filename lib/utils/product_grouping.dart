// Pure helpers to group product variants (sizes) by normalized name.

/// Lowercases, trims and collapses inner whitespace.
String normalizeProductName(String? name) =>
    (name ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Groups [items] by normalized name and keeps, per group, the item with the
/// highest score (first one wins on ties). Groups keep the order of their best
/// item (descending score). Items with an empty name are never merged: each is
/// kept on its own so no product is silently dropped.
List<T> groupBestByName<T>(
  List<T> items, {
  required String? Function(T item) nameOf,
  required double Function(T item) scoreOf,
  int? limit,
}) {
  final best = <String, T>{};
  final order = <String>[];
  var anonymous = 0;
  for (final item in items) {
    var key = normalizeProductName(nameOf(item));
    if (key.isEmpty) key = '__anon_${anonymous++}';
    final current = best[key];
    if (current == null) {
      best[key] = item;
      order.add(key);
    } else if (scoreOf(item) > scoreOf(current)) {
      best[key] = item;
    }
  }
  final result = order.map((k) => best[k] as T).toList();
  // Stable sort by descending score.
  final indexed = result.asMap().entries.toList()
    ..sort((a, b) {
      final c = scoreOf(b.value).compareTo(scoreOf(a.value));
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  final sorted = indexed.map((e) => e.value).toList();
  return limit == null || sorted.length <= limit
      ? sorted
      : sorted.sublist(0, limit);
}

/// Returns every product in [all] sharing the normalized name of [product]
/// (including [product] itself when present in [all]).
List<Map<String, dynamic>> siblingVariants(
  List<Map<String, dynamic>> all,
  Map<String, dynamic> product,
) {
  final key = normalizeProductName(product['name'] as String?);
  if (key.isEmpty) return [product];
  final result = all
      .where((p) => normalizeProductName(p['name'] as String?) == key)
      .toList();
  final id = product['id']?.toString();
  if (!result.any((p) => p['id']?.toString() == id)) result.add(product);
  return result;
}
