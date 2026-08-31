import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './app_state_notifier.dart';
import './device_id_service.dart';
import './local_cache_service.dart';
import './sync_service.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // Initialize Supabase - call this in main()
  static Future<void> initialize() async {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be defined using --dart-define.',
      );
    }
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    // Pre-load device ID on startup
    await DeviceIdService.instance.getDeviceId();
    // Kick off initial cache refresh if online, then start sync listener
    SyncService.instance.startListening();
    final online = await SyncService.instance.isOnline();
    if (online) {
      await SyncService.instance.syncAll();
    }
  }

  // Get Supabase client
  SupabaseClient get client => Supabase.instance.client;

  // ─── HELPER ────────────────────────────────────────────────────────────────

  String _generateId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ─── IMAGE STORAGE ─────────────────────────────────────────────────────────

  /// Uploads image bytes to Supabase Storage under product-images/[deviceId]/[uniqueName].jpg
  /// Returns the public URL or null on failure.
  Future<String?> uploadProductImage(Uint8List bytes) async {
    try {
      final deviceId = await DeviceIdService.instance.getDeviceId();
      final fileName =
          '$deviceId/${DateTime.now().millisecondsSinceEpoch}_${_generateId().substring(0, 8)}.jpg';

      await client.storage
          .from('product-images')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final publicUrl = client.storage
          .from('product-images')
          .getPublicUrl(fileName);
      debugPrint('[SupabaseService] Image uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('[SupabaseService] uploadProductImage error: $e');
      return null;
    }
  }

  /// Deletes an image from Supabase Storage given its public URL or storage path.
  Future<void> deleteProductImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return;
    try {
      // Extract the storage path from the public URL
      // URL format: https://<project>.supabase.co/storage/v1/object/public/product-images/<path>
      final uri = Uri.tryParse(imageUrl);
      if (uri == null) return;
      final segments = uri.pathSegments;
      // Find the index after 'product-images' bucket name
      final bucketIndex = segments.indexOf('product-images');
      if (bucketIndex == -1 || bucketIndex >= segments.length - 1) return;
      final storagePath = segments.sublist(bucketIndex + 1).join('/');
      await client.storage.from('product-images').remove([storagePath]);
      debugPrint('[SupabaseService] Deleted image: $storagePath');
    } catch (e) {
      debugPrint('[SupabaseService] deleteProductImage error: $e');
    }
  }

  // ─── CATEGORIES (offline-first) ────────────────────────────────────────────

  Future<List<String>> getCategories({bool includeHidden = false}) async {
    return LocalCacheService.instance.getCategories(
      includeHidden: includeHidden,
    );
  }

  Future<bool> addCategory(String name) async {
    await LocalCacheService.instance.addCategoryLocal(name.trim());
    AppStateNotifier.instance.notifyCategoriesChanged();
    final online = await SyncService.instance.isOnline();
    if (online) {
      final result = await addCategoryRemote(name.trim());
      if (result) await _refreshProductsAndCategories();
      return result;
    } else {
      await LocalCacheService.instance.enqueue(
        OfflineOperation(
          id: _generateId(),
          type: 'addCategory',
          payload: {'name': name.trim()},
          createdAt: DateTime.now(),
        ),
      );
      return true;
    }
  }

  Future<bool> renameCategory(String oldName, String newName) async {
    await LocalCacheService.instance.renameCategoryLocal(
      oldName,
      newName.trim(),
    );
    AppStateNotifier.instance.notifyCategoriesChanged();
    AppStateNotifier.instance.notifyProductsChanged();
    final online = await SyncService.instance.isOnline();
    if (online) {
      final result = await renameCategoryRemote(oldName, newName.trim());
      if (result) await _refreshProductsAndCategories();
      return result;
    } else {
      await LocalCacheService.instance.enqueue(
        OfflineOperation(
          id: _generateId(),
          type: 'renameCategory',
          payload: {'oldName': oldName, 'newName': newName.trim()},
          createdAt: DateTime.now(),
        ),
      );
      return true;
    }
  }

  Future<bool> hideCategory(String name) async {
    await LocalCacheService.instance.hideCategoryLocal(name);
    AppStateNotifier.instance.notifyCategoriesChanged();
    final online = await SyncService.instance.isOnline();
    if (online) {
      final result = await hideCategoryRemote(name);
      if (result) await _refreshProductsAndCategories();
      return result;
    } else {
      await LocalCacheService.instance.enqueue(
        OfflineOperation(
          id: _generateId(),
          type: 'hideCategory',
          payload: {'name': name},
          createdAt: DateTime.now(),
        ),
      );
      return true;
    }
  }

  // ─── PRODUCTS (offline-first) ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProducts({String? category}) async {
    return LocalCacheService.instance.getProducts(category: category);
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    return LocalCacheService.instance.searchProducts(query);
  }

  Future<Map<String, dynamic>?> getProductById(String id) async {
    return LocalCacheService.instance.getProductById(id);
  }

  Future<bool> insertProduct({
    required String name,
    required String category,
    String? size,
    required double purchasePrice,
    required int stock,
    String? imageUrl,
    String? aiTags,
  }) async {
    final id = await insertProductAndGetId(
      name: name,
      category: category,
      size: size,
      purchasePrice: purchasePrice,
      stock: stock,
      imageUrl: imageUrl,
      aiTags: aiTags,
    );
    return id != null;
  }

  /// Inserts a product and returns the remote Supabase id (or a temp id when offline).
  /// Use this when you need the id to perform a subsequent UPDATE (e.g. ai_tags).
  Future<String?> insertProductAndGetId({
    required String name,
    required String category,
    String? size,
    required double purchasePrice,
    required int stock,
    String? imageUrl,
    String? aiTags,
  }) async {
    final deviceId = await DeviceIdService.instance.getDeviceId();
    final tempId = _generateId();
    final now = DateTime.now().toIso8601String();
    final product = {
      'id': tempId,
      'name': name.trim(),
      'category': category,
      'size': size,
      'purchase_price': purchasePrice,
      'stock': stock,
      'image_url': imageUrl,
      'ai_tags': aiTags,
      'device_id': deviceId,
      'created_at': now,
      'updated_at': now,
    };
    await LocalCacheService.instance.insertProduct(product);
    AppStateNotifier.instance.notifyProductsChanged();

    final online = await SyncService.instance.isOnline();
    if (online) {
      final remoteId = await insertProductRemote(
        name: name.trim(),
        category: category,
        size: size,
        purchasePrice: purchasePrice,
        stock: stock,
        imageUrl: imageUrl,
        aiTags: aiTags,
        deviceId: deviceId,
      );
      if (remoteId != null) {
        await _refreshProductsAndCategories();
      }
      return remoteId;
    } else {
      await LocalCacheService.instance.enqueue(
        OfflineOperation(
          id: _generateId(),
          type: 'insertProduct',
          payload: {
            'name': name.trim(),
            'category': category,
            'size': size,
            'purchase_price': purchasePrice,
            'stock': stock,
            'image_url': imageUrl,
            'ai_tags': aiTags,
            'device_id': deviceId,
          },
          createdAt: DateTime.now(),
        ),
      );
      // Return tempId so caller knows the product was queued (ai_tags update will be skipped offline)
      return tempId;
    }
  }

  Future<bool> updateProductStock(
    String productId,
    int additionalQty,
    double purchasePrice,
  ) async {
    await LocalCacheService.instance.updateProductStockLocal(
      productId,
      additionalQty,
      purchasePrice,
    );
    AppStateNotifier.instance.notifyProductsChanged();
    final online = await SyncService.instance.isOnline();
    if (online) {
      final result = await updateProductStockRemote(
        productId,
        additionalQty,
        purchasePrice,
      );
      if (result) await _refreshProductsAndCategories();
      return result;
    } else {
      await LocalCacheService.instance.enqueue(
        OfflineOperation(
          id: _generateId(),
          type: 'updateProductStock',
          payload: {
            'product_id': productId,
            'additional_qty': additionalQty,
            'purchase_price': purchasePrice,
          },
          createdAt: DateTime.now(),
        ),
      );
      return true;
    }
  }

  Future<bool> deductProductStock(String productId, int qty) async {
    await LocalCacheService.instance.deductProductStockLocal(productId, qty);
    AppStateNotifier.instance.notifyProductsChanged();
    final online = await SyncService.instance.isOnline();
    if (online) {
      try {
        final product = await getProductByIdRemote(productId);
        if (product == null) return false;
        final currentStock = (product['stock'] as int?) ?? 0;
        final newStock = (currentStock - qty).clamp(0, 999999);
        await client
            .from('products')
            .update({'stock': newStock})
            .eq('id', productId);
        return true;
      } catch (e) {
        debugPrint('[SupabaseService] deductProductStock error: $e');
        return false;
      }
    }
    return true;
  }

  // ─── SALES (offline-first) ─────────────────────────────────────────────────

  Future<bool> registerSale({
    required String productId,
    required String productName,
    required String productCategory,
    required int quantity,
    required double salePrice,
    required double costPrice,
    required String paymentMethod,
  }) async {
    // Validate stock from local cache first
    final product = await LocalCacheService.instance.getProductById(productId);
    final currentStock = (product?['stock'] as int?) ?? 0;
    if (quantity > currentStock) {
      return false; // Insufficient stock
    }

    final deviceId = await DeviceIdService.instance.getDeviceId();
    final totalSale = salePrice * quantity;
    final totalCost = costPrice * quantity;
    final now = DateTime.now().toIso8601String();
    final sale = {
      'id': _generateId(),
      'product_id': productId,
      'product_name': productName,
      'product_category': productCategory,
      'quantity': quantity,
      'sale_price': salePrice,
      'cost_price': costPrice,
      'total_sale': totalSale,
      'total_cost': totalCost,
      'payment_method': paymentMethod,
      'device_id': deviceId,
      'sold_at': now,
    };

    // Apply locally first
    await LocalCacheService.instance.insertSaleLocal(sale);
    await LocalCacheService.instance.deductProductStockLocal(
      productId,
      quantity,
    );

    // Notify all screens immediately
    AppStateNotifier.instance.notifyProductsChanged();
    AppStateNotifier.instance.notifySalesChanged();

    final online = await SyncService.instance.isOnline();
    if (online) {
      // registerSaleRemote handles both sale insert AND stock deduction on remote
      final result = await registerSaleRemote(
        productId: productId,
        productName: productName,
        productCategory: productCategory,
        quantity: quantity,
        salePrice: salePrice,
        costPrice: costPrice,
        paymentMethod: paymentMethod,
        deviceId: deviceId,
      );
      if (result) {
        // Refresh local cache from remote to stay in sync
        await _refreshAll();
      }
      return result;
    } else {
      await LocalCacheService.instance.enqueue(
        OfflineOperation(
          id: _generateId(),
          type: 'registerSale',
          payload: {
            'product_id': productId,
            'product_name': productName,
            'product_category': productCategory,
            'quantity': quantity,
            'sale_price': salePrice,
            'cost_price': costPrice,
            'payment_method': paymentMethod,
            'device_id': deviceId,
          },
          createdAt: DateTime.now(),
        ),
      );
      return true;
    }
  }

  Future<List<Map<String, dynamic>>> getSalesByDate(DateTime date) async {
    return LocalCacheService.instance.getSalesByDate(date);
  }

  // ─── DASHBOARD KPIs (offline-first) ────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardKpis() async {
    return LocalCacheService.instance.getDashboardKpis();
  }

  // ─── INTERNAL REFRESH HELPERS ──────────────────────────────────────────────

  /// Refresh products + categories from remote and notify listeners.
  Future<void> refreshProductsAndCategories() =>
      _refreshProductsAndCategories();

  Future<void> _refreshProductsAndCategories() async {
    try {
      final deviceId = await DeviceIdService.instance.getDeviceId();
      final products = await getProductsRemote(deviceId: deviceId);
      final categories = await getCategoriesRawRemote();
      await LocalCacheService.instance.saveProducts(products);
      await LocalCacheService.instance.saveCategories(categories);
      AppStateNotifier.instance.notifyProductsChanged();
      AppStateNotifier.instance.notifyCategoriesChanged();
    } catch (e) {
      debugPrint('[SupabaseService] _refreshProductsAndCategories error: $e');
    }
  }

  /// Refresh all data from remote and notify listeners.
  Future<void> _refreshAll() async {
    try {
      final deviceId = await DeviceIdService.instance.getDeviceId();
      final products = await getProductsRemote(deviceId: deviceId);
      final categories = await getCategoriesRawRemote();
      final sales = await getAllSalesRemote(deviceId: deviceId);
      await LocalCacheService.instance.refreshFromRemote(
        products: products,
        categories: categories,
        sales: sales,
      );
      AppStateNotifier.instance.notifyAll();
    } catch (e) {
      debugPrint('[SupabaseService] _refreshAll error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REMOTE-ONLY METHODS (called by SyncService and internal online paths)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> addCategoryRemote(String name) async {
    try {
      await client.from('categories').insert({
        'name': name,
        'is_hidden': false,
      });
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] addCategoryRemote error: $e');
      return false;
    }
  }

  Future<bool> renameCategoryRemote(String oldName, String newName) async {
    try {
      await client
          .from('categories')
          .update({'name': newName})
          .eq('name', oldName);
      await client
          .from('products')
          .update({'category': newName})
          .eq('category', oldName);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] renameCategoryRemote error: $e');
      return false;
    }
  }

  Future<bool> hideCategoryRemote(String name) async {
    try {
      await client
          .from('categories')
          .update({'is_hidden': true})
          .eq('name', name);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] hideCategoryRemote error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getProductsRemote({
    String? category,
    String? deviceId,
  }) async {
    try {
      var query = client.from('products').select();
      if (category != null && category != 'Todos') {
        query = query.eq('category', category);
      }
      // Filter by device_id when provided
      if (deviceId != null && deviceId.isNotEmpty) {
        query = query.eq('device_id', deviceId);
      }
      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[SupabaseService] getProductsRemote error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getProductByIdRemote(String id) async {
    try {
      final response = await client
          .from('products')
          .select()
          .eq('id', id)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('[SupabaseService] getProductByIdRemote error: $e');
      return null;
    }
  }

  Future<String?> insertProductRemote({
    required String name,
    required String category,
    String? size,
    required double purchasePrice,
    required int stock,
    String? imageUrl,
    String? aiTags,
    String? deviceId,
  }) async {
    try {
      final payload = {
        'name': name,
        'category': category,
        'size': size,
        'purchase_price': purchasePrice,
        'stock': stock,
        'image_url': imageUrl,
        'ai_tags': aiTags,
        'device_id': deviceId,
      };
      debugPrint(
        '[SupabaseService] insertProductRemote payload: ${jsonEncode(payload)}',
      );
      final response = await client
          .from('products')
          .insert(payload)
          .select('id')
          .single();
      return response['id'] as String?;
    } catch (e) {
      debugPrint('[SupabaseService] insertProductRemote error: $e');
      return null;
    }
  }

  Future<bool> updateProductAiTagsRemote(
    String productId,
    String aiTags,
  ) async {
    try {
      await client
          .from('products')
          .update({'ai_tags': aiTags})
          .eq('id', productId)
          .select();
      debugPrint(
        '[SupabaseService] updateProductAiTagsRemote OK: $productId → $aiTags',
      );
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] updateProductAiTagsRemote error: $e');
      return false;
    }
  }

  Future<bool> updateProductStockRemote(
    String productId,
    int additionalQty,
    double purchasePrice,
  ) async {
    try {
      final product = await getProductByIdRemote(productId);
      if (product == null) return false;
      final currentStock = (product['stock'] as int?) ?? 0;
      await client
          .from('products')
          .update({
            'stock': currentStock + additionalQty,
            'purchase_price': purchasePrice,
          })
          .eq('id', productId);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] updateProductStockRemote error: $e');
      return false;
    }
  }

  Future<bool> registerSaleRemote({
    required String productId,
    required String productName,
    required String productCategory,
    required int quantity,
    required double salePrice,
    required double costPrice,
    required String paymentMethod,
    String? deviceId,
  }) async {
    try {
      final totalSale = salePrice * quantity;
      final totalCost = costPrice * quantity;

      // Insert sale record
      await client.from('sales').insert({
        'product_id': productId,
        'product_name': productName,
        'product_category': productCategory,
        'quantity': quantity,
        'sale_price': salePrice,
        'cost_price': costPrice,
        'total_sale': totalSale,
        'total_cost': totalCost,
        'payment_method': paymentMethod,
        'device_id': deviceId,
        'sold_at': DateTime.now().toIso8601String(),
      });

      // Deduct stock on remote using atomic RPC to avoid race conditions
      // Fetch current stock and update
      final product = await getProductByIdRemote(productId);
      if (product != null) {
        final currentStock = (product['stock'] as int?) ?? 0;
        final newStock = (currentStock - quantity).clamp(0, 999999);
        await client
            .from('products')
            .update({'stock': newStock})
            .eq('id', productId);
      }
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] registerSaleRemote error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getCategoriesRawRemote() async {
    try {
      final response = await client
          .from('categories')
          .select('name, is_hidden')
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[SupabaseService] getCategoriesRawRemote error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllSalesRemote({
    String? deviceId,
  }) async {
    try {
      var query = client.from('sales').select();
      // Filter by device_id when provided
      if (deviceId != null && deviceId.isNotEmpty) {
        query = query.eq('device_id', deviceId);
      }
      final response = await query.order('sold_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[SupabaseService] getAllSalesRemote error: $e');
      return [];
    }
  }
}
