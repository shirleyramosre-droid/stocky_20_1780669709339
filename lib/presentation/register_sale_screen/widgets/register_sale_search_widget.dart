import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class RegisterSaleSearchWidget extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final TextEditingController? controller;

  const RegisterSaleSearchWidget({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onSearchChanged,
        decoration: const InputDecoration(
          hintText: 'Buscar producto...',
          hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppTheme.textMuted,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
