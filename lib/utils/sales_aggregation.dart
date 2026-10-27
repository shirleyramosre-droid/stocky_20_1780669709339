// Pure helpers to aggregate sales rows by product name.

class SoldProduct {
  final String name;
  final int quantity;
  const SoldProduct(this.name, this.quantity);
}

DateTime? _parseSoldAt(dynamic raw) {
  if (raw is! String) return null;
  final parsed = DateTime.tryParse(raw);
  return parsed?.toLocal();
}

/// Aggregates [sales] sold between [start] and [end] (both inclusive, by
/// calendar day in local time) into total quantity per product name.
///
/// Names are grouped case-insensitively ignoring extra spaces; the first
/// spelling seen is kept for display. Result is sorted by quantity descending,
/// then by name.
List<SoldProduct> aggregateSalesByName(
  List<Map<String, dynamic>> sales,
  DateTime start,
  DateTime end,
) {
  final from = DateTime(start.year, start.month, start.day);
  final toExclusive = DateTime(end.year, end.month, end.day + 1);
  final names = <String, String>{};
  final totals = <String, int>{};
  for (final s in sales) {
    final soldAt = _parseSoldAt(s['sold_at']);
    if (soldAt == null) continue;
    if (soldAt.isBefore(from) || !soldAt.isBefore(toExclusive)) continue;
    final rawName = ((s['product_name'] as String?) ?? '').trim();
    if (rawName.isEmpty) continue;
    final key = rawName.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    names.putIfAbsent(key, () => rawName);
    totals[key] = (totals[key] ?? 0) + ((s['quantity'] as num?)?.toInt() ?? 0);
  }
  final list =
      totals.entries.map((e) => SoldProduct(names[e.key]!, e.value)).toList()
        ..sort((a, b) {
          final c = b.quantity.compareTo(a.quantity);
          return c != 0
              ? c
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
  return list;
}
