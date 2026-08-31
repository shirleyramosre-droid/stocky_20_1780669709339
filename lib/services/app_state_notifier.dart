import 'package:flutter/foundation.dart';

/// Global notifier for cross-screen data refresh.
/// Any screen that modifies inventory/sales/products should call the
/// appropriate notify method. Screens that display that data should
/// listen and reload when notified.
class AppStateNotifier {
  static final AppStateNotifier instance = AppStateNotifier._();
  AppStateNotifier._();

  /// Increments every time products/inventory changes.
  final ValueNotifier<int> productsVersion = ValueNotifier<int>(0);

  /// Increments every time a sale is registered.
  final ValueNotifier<int> salesVersion = ValueNotifier<int>(0);

  /// Increments every time categories change.
  final ValueNotifier<int> categoriesVersion = ValueNotifier<int>(0);

  void notifyProductsChanged() {
    productsVersion.value++;
  }

  void notifySalesChanged() {
    salesVersion.value++;
  }

  void notifyCategoriesChanged() {
    categoriesVersion.value++;
  }

  void notifyAll() {
    productsVersion.value++;
    salesVersion.value++;
    categoriesVersion.value++;
  }
}
