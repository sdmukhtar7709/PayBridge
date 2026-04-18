import 'package:flutter/material.dart';

class Responsive {
  const Responsive._();

  static double scaleFactor(BuildContext context, {double baseWidth = 375}) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / baseWidth).clamp(0.85, 1.30).toDouble();
  }

  static double fs(BuildContext context, double size) {
    return size * scaleFactor(context);
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= 900 ? 24.0 : (width >= 600 ? 20.0 : 16.0);
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: 12);
  }

  static double contentMaxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1100) return 860;
    if (width >= 800) return 720;
    if (width >= 600) return 640;
    return double.infinity;
  }
}