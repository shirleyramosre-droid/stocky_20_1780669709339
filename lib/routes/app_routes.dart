import 'package:flutter/material.dart';

import '../presentation/configure_category_screen/configure_category_screen.dart';
import '../presentation/existing_product_entry_screen/existing_product_entry_screen.dart';
import '../presentation/gemini_diagnostic_screen/gemini_diagnostic_screen.dart';
import '../presentation/home_screen/home_screen.dart';
import '../presentation/new_product_entry_screen/new_product_entry_screen.dart';
import '../presentation/product_catalog_screen/product_catalog_screen.dart';
import '../presentation/product_detail_screen/product_detail_screen.dart';
import '../presentation/register_sale_screen/register_sale_screen.dart';
import '../presentation/sales_history_screen/sales_history_screen.dart';
import '../presentation/stock_alerts_screen/stock_alerts_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String homeScreen = '/home-screen';
  static const String newProductEntryScreen = '/new-product-entry-screen';
  static const String existingProductEntryScreen =
      '/existing-product-entry-screen';
  static const String registerSaleScreen = '/register-sale-screen';
  static const String productCatalogScreen = '/product-catalog-screen';
  static const String productDetailScreen = '/product-detail-screen';
  static const String salesHistoryScreen = '/sales-history-screen';
  static const String configureCategoryScreen = '/configure-category-screen';
  static const String stockAlertsScreen = '/stock-alerts-screen';
  static const String geminiDiagnosticScreen = '/gemini-diagnostic-screen';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const HomeScreen(),
    homeScreen: (context) => const HomeScreen(),
    newProductEntryScreen: (context) => const NewProductEntryScreen(),
    existingProductEntryScreen: (context) => const ExistingProductEntryScreen(),
    registerSaleScreen: (context) => const RegisterSaleScreen(),
    productCatalogScreen: (context) => const ProductCatalogScreen(),
    productDetailScreen: (context) => const ProductDetailScreen(),
    salesHistoryScreen: (context) => const SalesHistoryScreen(),
    configureCategoryScreen: (context) => const ConfigureCategoryScreen(),
    stockAlertsScreen: (context) => const StockAlertsScreen(),
    geminiDiagnosticScreen: (context) => const GeminiDiagnosticScreen(),
  };
}
