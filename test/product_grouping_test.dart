import 'package:flutter_test/flutter_test.dart';
import 'package:stocky/utils/product_grouping.dart';

Map<String, dynamic> p(String id, String name, String size, double score) => {
  'id': id,
  'name': name,
  'size': size,
  'score': score,
};

void main() {
  test('normalizeProductName trims, lowercases and collapses spaces', () {
    expect(normalizeProductName('  Polo   AZUL '), 'polo azul');
    expect(normalizeProductName(null), '');
  });

  test('groupBestByName keeps best per name and applies limit', () {
    final items = [
      p('1', 'Polo Azul', 'S', 0.5),
      p('2', 'polo  azul', 'M', 0.9),
      p('3', 'Casaca', 'L', 0.7),
      p('4', 'Short', 'M', 0.6),
      p('5', 'Medias', 'U', 0.1),
    ];
    final r = groupBestByName<Map<String, dynamic>>(
      items,
      nameOf: (e) => e['name'] as String,
      scoreOf: (e) => e['score'] as double,
      limit: 3,
    );
    expect(r.map((e) => e['id']), ['2', '3', '4']);
  });

  test('siblingVariants returns all sizes of the same normalized name', () {
    final all = [
      p('1', 'Polo Azul', 'S', 0),
      p('2', 'polo azul ', 'M', 0),
      p('3', 'Casaca', 'L', 0),
    ];
    final r = siblingVariants(all, all[0]);
    expect(r.map((e) => e['id']), ['1', '2']);
  });
}
