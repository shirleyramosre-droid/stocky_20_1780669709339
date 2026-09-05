import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../routes/app_routes.dart';

class AppNavigationDrawer extends StatelessWidget {
  final String activeRoute;

  const AppNavigationDrawer({super.key, required this.activeRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.drawerBg,
      child: Column(
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.drawerHeader, AppTheme.primaryDark],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withAlpha(102),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.checkroom_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Stocky',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gestión de Inventario',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withAlpha(179),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _DrawerItem(
                  icon: Icons.home_rounded,
                  label: 'Inicio',
                  route: AppRoutes.homeScreen,
                  isActive:
                      activeRoute == AppRoutes.homeScreen ||
                      activeRoute == AppRoutes.initial,
                ),
                _DrawerItem(
                  icon: Icons.add_box_rounded,
                  label: 'Ingreso de Prendas Nuevas',
                  route: AppRoutes.newProductEntryScreen,
                  isActive: activeRoute == AppRoutes.newProductEntryScreen,
                ),
                _DrawerItem(
                  icon: Icons.inventory_2_rounded,
                  label: 'Ingreso de Prendas Existentes',
                  route: AppRoutes.existingProductEntryScreen,
                  isActive: activeRoute == AppRoutes.existingProductEntryScreen,
                ),
                _DrawerItem(
                  icon: Icons.point_of_sale_rounded,
                  label: 'Registrar Venta',
                  route: AppRoutes.registerSaleScreen,
                  isActive: activeRoute == AppRoutes.registerSaleScreen,
                ),
                _DrawerItem(
                  icon: Icons.category_rounded,
                  label: 'Configurar Categoría',
                  route: AppRoutes.configureCategoryScreen,
                  isActive: activeRoute == AppRoutes.configureCategoryScreen,
                ),
                _DrawerItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Historial de Ventas',
                  route: AppRoutes.salesHistoryScreen,
                  isActive: activeRoute == AppRoutes.salesHistoryScreen,
                ),
                _DrawerItem(
                  icon: Icons.warning_amber_rounded,
                  label: 'Alertas de Stock',
                  route: AppRoutes.stockAlertsScreen,
                  isActive: activeRoute == AppRoutes.stockAlertsScreen,
                ),
                _DrawerItem(
                  icon: Icons.style_rounded,
                  label: 'Catálogo de Prendas',
                  route: AppRoutes.productCatalogScreen,
                  isActive: activeRoute == AppRoutes.productCatalogScreen,
                ),
                _DrawerItem(
                  icon: Icons.biotech_rounded,
                  label: 'Diagnóstico Gemini',
                  route: AppRoutes.geminiDiagnosticScreen,
                  isActive: activeRoute == AppRoutes.geminiDiagnosticScreen,
                ),
                _DrawerItem(
                  icon: Icons.vpn_key_rounded,
                  label: 'Configuración de API',
                  route: AppRoutes.apiSettingsScreen,
                  isActive: activeRoute == AppRoutes.apiSettingsScreen,
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(51),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi Tienda',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'v1.0.0',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? route;
  final bool isActive;
  final String? badge;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          splashColor: AppTheme.primary.withAlpha(51),
          onTap: () {
            Navigator.pop(context);
            if (route != null) {
              Navigator.pushNamed(context, route!);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.primary.withAlpha(46)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: AppTheme.primary.withAlpha(102), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? AppTheme.primary : const Color(0xFF888888),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? Colors.white : const Color(0xFFBBBBBB),
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.cancelRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}