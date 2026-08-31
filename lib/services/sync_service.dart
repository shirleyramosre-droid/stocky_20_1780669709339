import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import './app_state_notifier.dart';
import './device_id_service.dart';
import './local_cache_service.dart';
import './supabase_service.dart';

class SyncService {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();
  SyncService._();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isSyncing = false;

  /// Start listening for connectivity changes and trigger sync on reconnect.
  void startListening() {
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        await syncAll();
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Check current connectivity.
  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Sync all queued offline operations to Supabase, then refresh local cache.
  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _processQueue();
      await _refreshLocalCache();
      // Notify all screens after sync
      AppStateNotifier.instance.notifyAll();
    } catch (e) {
      debugPrint('[SyncService] syncAll error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Replay each queued operation against Supabase in order.
  Future<void> _processQueue() async {
    final queue = await LocalCacheService.instance.getQueue();
    if (queue.isEmpty) return;

    final svc = SupabaseService.instance;
    for (final op in queue) {
      try {
        bool success = false;
        switch (op.type) {
          case 'addCategory':
            success = await svc.addCategoryRemote(op.payload['name'] as String);
            break;
          case 'renameCategory':
            success = await svc.renameCategoryRemote(
              op.payload['oldName'] as String,
              op.payload['newName'] as String,
            );
            break;
          case 'hideCategory':
            success = await svc.hideCategoryRemote(
              op.payload['name'] as String,
            );
            break;
          case 'insertProduct':
            final insertedId = await svc.insertProductRemote(
              name: op.payload['name'] as String,
              category: op.payload['category'] as String,
              size: op.payload['size'] as String?,
              purchasePrice: (op.payload['purchase_price'] as num).toDouble(),
              stock: op.payload['stock'] as int,
              imageUrl: op.payload['image_url'] as String?,
              aiTags: op.payload['ai_tags'] as String?,
              deviceId: op.payload['device_id'] as String?,
            );
            success = insertedId != null;
            break;
          case 'updateProductStock':
            success = await svc.updateProductStockRemote(
              op.payload['product_id'] as String,
              op.payload['additional_qty'] as int,
              (op.payload['purchase_price'] as num).toDouble(),
            );
            break;
          case 'registerSale':
            success = await svc.registerSaleRemote(
              productId: op.payload['product_id'] as String,
              productName: op.payload['product_name'] as String,
              productCategory: op.payload['product_category'] as String,
              quantity: op.payload['quantity'] as int,
              salePrice: (op.payload['sale_price'] as num).toDouble(),
              costPrice: (op.payload['cost_price'] as num).toDouble(),
              paymentMethod: op.payload['payment_method'] as String,
              deviceId: op.payload['device_id'] as String?,
            );
            break;
        }
        if (success) {
          await LocalCacheService.instance.removeFromQueue(op.id);
          debugPrint('[SyncService] Synced op ${op.type} (${op.id})');
        }
      } catch (e) {
        debugPrint('[SyncService] Failed to sync op ${op.type}: $e');
        // Leave in queue to retry next time
      }
    }
  }

  /// Pull fresh data from Supabase and update local cache.
  Future<void> _refreshLocalCache() async {
    try {
      final svc = SupabaseService.instance;
      final deviceId = await DeviceIdService.instance.getDeviceId();
      final products = await svc.getProductsRemote(deviceId: deviceId);
      final categories = await svc.getCategoriesRawRemote();
      final sales = await svc.getAllSalesRemote(deviceId: deviceId);
      await LocalCacheService.instance.refreshFromRemote(
        products: products,
        categories: categories,
        sales: sales,
      );
      debugPrint('[SyncService] Local cache refreshed from Supabase');
    } catch (e) {
      debugPrint('[SyncService] Cache refresh error: $e');
    }
  }
}
