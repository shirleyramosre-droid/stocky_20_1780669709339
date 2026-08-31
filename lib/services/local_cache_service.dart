import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys used in SharedPreferences
class _Keys {
  static const String products = 'local_products';
  static const String categories = 'local_categories';
  static const String sales = 'local_sales';
  static const String offlineQueue = 'offline_queue';
}

/// Represents a queued offline operation to be synced later.
class OfflineOperation {
  final String id;
  final String
  type; // 'addCategory','renameCategory','hideCategory','insertProduct','updateProductStock','registerSale'
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  OfflineOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
  };

  factory OfflineOperation.fromJson(Map<String, dynamic> json) =>
      OfflineOperation(
        id: json['id'] as String,
        type: json['type'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class LocalCacheService {
  static LocalCacheService? _instance;
  static LocalCacheService get instance => _instance ??= LocalCacheService._();
  LocalCacheService._();

  // ─── PRODUCTS ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProducts({String? category}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_Keys.products);
    if (raw == null) return [];
    final list = List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    if (category != null && category != 'Todos') {
      return list.where((p) => p['category'] == category).toList();
    }
    return list;
  }

  Future<void> saveProducts(List<Map<String, dynamic>> products) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_Keys.products, jsonEncode(products));
  }

  Future<Map<String, dynamic>?> getProductById(String id) async {
    final products = await getProducts();
    try {
      return products.firstWhere((p) => p['id']?.toString() == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    if (query.isEmpty) return [];
    final products = await getProducts();
    final q = query.toLowerCase();
    return products
        .where((p) => (p['name'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  /// Inserts a product into the local cache (used for offline inserts).
  Future<void> insertProduct(Map<String, dynamic> product) async {
    final products = await getProducts();
    products.insert(0, product);
    await saveProducts(products);
  }

  /// Updates stock for a product in the local cache.
  Future<void> updateProductStockLocal(
    String productId,
    int additionalQty,
    double purchasePrice,
  ) async {
    final products = await getProducts();
    final idx = products.indexWhere((p) => p['id']?.toString() == productId);
    if (idx != -1) {
      final current = (products[idx]['stock'] as int?) ?? 0;
      products[idx]['stock'] = current + additionalQty;
      products[idx]['purchase_price'] = purchasePrice;
      await saveProducts(products);
    }
  }

  /// Deducts stock for a product in the local cache.
  Future<void> deductProductStockLocal(String productId, int qty) async {
    final products = await getProducts();
    final idx = products.indexWhere((p) => p['id']?.toString() == productId);
    if (idx != -1) {
      final current = (products[idx]['stock'] as int?) ?? 0;
      products[idx]['stock'] = (current - qty).clamp(0, 999999);
      await saveProducts(products);
    }
  }

  // ─── CATEGORIES ────────────────────────────────────────────────────────────

  Future<List<String>> getCategories({bool includeHidden = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_Keys.categories);
    if (raw == null) return [];
    final list = List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    if (!includeHidden) {
      return list
          .where((c) => c['is_hidden'] != true)
          .map((c) => c['name'] as String)
          .toList();
    }
    return list.map((c) => c['name'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getCategoriesRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_Keys.categories);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<void> saveCategories(List<Map<String, dynamic>> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_Keys.categories, jsonEncode(categories));
  }

  Future<void> addCategoryLocal(String name) async {
    final cats = await getCategoriesRaw();
    if (!cats.any((c) => c['name'] == name)) {
      cats.add({'name': name, 'is_hidden': false});
      await saveCategories(cats);
    }
  }

  Future<void> renameCategoryLocal(String oldName, String newName) async {
    final cats = await getCategoriesRaw();
    for (final c in cats) {
      if (c['name'] == oldName) c['name'] = newName;
    }
    await saveCategories(cats);
    // Also update products
    final products = await getProducts();
    for (final p in products) {
      if (p['category'] == oldName) p['category'] = newName;
    }
    await saveProducts(products);
  }

  Future<void> hideCategoryLocal(String name) async {
    final cats = await getCategoriesRaw();
    for (final c in cats) {
      if (c['name'] == name) c['is_hidden'] = true;
    }
    await saveCategories(cats);
  }

  // ─── SALES ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSalesByDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_Keys.sales);
    if (raw == null) return [];
    final all = List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    return all.where((s) {
      final soldAt = DateTime.tryParse(s['sold_at'] as String? ?? '');
      if (soldAt == null) return false;
      return soldAt.year == date.year &&
          soldAt.month == date.month &&
          soldAt.day == date.day;
    }).toList()..sort(
      (a, b) => (b['sold_at'] as String).compareTo(a['sold_at'] as String),
    );
  }

  Future<void> insertSaleLocal(Map<String, dynamic> sale) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_Keys.sales);
    final all = raw == null
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            (jsonDecode(raw) as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          );
    all.insert(0, sale);
    await prefs.setString(_Keys.sales, jsonEncode(all));
  }

  Future<void> saveSales(List<Map<String, dynamic>> sales) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_Keys.sales, jsonEncode(sales));
  }

  Future<List<Map<String, dynamic>>> getAllSales() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_Keys.sales);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  // ─── DASHBOARD KPIs ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardKpis() async {
    final today = DateTime.now();
    final todaySales = await getSalesByDate(today);
    double totalSales = 0;
    double totalCost = 0;
    for (final s in todaySales) {
      totalSales += (s['total_sale'] as num?)?.toDouble() ?? 0;
      totalCost += (s['total_cost'] as num?)?.toDouble() ?? 0;
    }
    final products = await getProducts();
    final lowStock =
        products.where((p) => ((p['stock'] as int?) ?? 0) <= 3).toList()..sort(
          (a, b) =>
              ((a['stock'] as int?) ?? 0).compareTo((b['stock'] as int?) ?? 0),
        );
    return {
      'todaySales': totalSales,
      'todayProfit': totalSales - totalCost,
      'todayTransactions': todaySales.length,
      'lowStockProducts': lowStock,
    };
  }

  // ─── OFFLINE QUEUE ─────────────────────────────────────────────────────────

  Future<List<OfflineOperation>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_Keys.offlineQueue);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (e) => OfflineOperation.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> enqueue(OfflineOperation op) async {
    final queue = await getQueue();
    queue.add(op);
    await _saveQueue(queue);
  }

  Future<void> removeFromQueue(String opId) async {
    final queue = await getQueue();
    queue.removeWhere((op) => op.id == opId);
    await _saveQueue(queue);
  }

  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_Keys.offlineQueue);
  }

  Future<void> _saveQueue(List<OfflineOperation> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _Keys.offlineQueue,
      jsonEncode(queue.map((op) => op.toJson()).toList()),
    );
  }

  // ─── FULL CACHE REFRESH ────────────────────────────────────────────────────

  /// Replaces the entire local cache with fresh data from Supabase.
  Future<void> refreshFromRemote({
    required List<Map<String, dynamic>> products,
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> sales,
  }) async {
    await saveProducts(products);
    await saveCategories(categories);
    await saveSales(sales);
  }
}
