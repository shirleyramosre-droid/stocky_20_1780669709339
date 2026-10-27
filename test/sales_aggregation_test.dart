import 'package:flutter_test/flutter_test.dart';
import 'package:stocky/utils/sales_aggregation.dart';

Map<String, dynamic> sale(String name, int qty, String soldAt) => {
  'product_name': name,
  'quantity': qty,
  'sold_at': soldAt,
};

void main() {
  test('aggregates by name within range, inclusive of end day', () {
    final sales = [
      sale('Polo', 2, '2026-10-01T09:00:00'),
      sale('polo ', 3, '2026-10-03T23:59:00'),
      sale('Casaca', 1, '2026-10-02T10:00:00'),
      sale('Polo', 5, '2026-10-04T00:00:00'),
      sale('Short', 4, '2026-09-30T23:59:00'),
    ];
    final r = aggregateSalesByName(
      sales,
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 3),
    );
    expect(r.map((e) => '${e.name}:${e.quantity}'), ['Polo:5', 'Casaca:1']);
  });

  test('ignores invalid dates and empty names', () {
    final r = aggregateSalesByName(
      [sale('', 1, '2026-10-01T09:00:00'), sale('X', 1, 'bad')],
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 1),
    );
    expect(r, isEmpty);
  });
}
