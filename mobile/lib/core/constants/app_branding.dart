import 'package:flutter/material.dart';

/// Central branding and customizable asset configuration.
/// In the future, to rebrand the application or replace logos/icons:
/// 1. Replace the file in `assets/images/logo.png` or `assets/images/frostpro_logo.png`
/// 2. Or simply change the file path constant below.
class AppBranding {
  // Brand Names & Tagline
  static const String appName = 'FrostPro';
  static const String appTagline = 'Enterprise Air Conditioning Service & HVAC Operations';
  static const String companyName = 'FrostPro AC Solutions Pvt Ltd';
  static const String supportPhone = '+91 98765 43210';
  static const String supportEmail = 'support@frostpro.in';

  // Asset Paths (Customizable)
  static const String appLogo = 'assets/images/frostpro_logo.png';
  static const String appIcon = 'assets/images/frostpro_logo.png';
  
  // Custom Logo Widget helper with fallback gracefully handled
  static Widget buildLogo({
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    BorderRadius? borderRadius,
  }) {
    Widget imageWidget = Image.asset(
      appLogo,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width ?? 60,
          height: height ?? 60,
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withValues(alpha: 0.1),
            borderRadius: borderRadius ?? BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.ac_unit, color: Color(0xFF0284C7), size: 32),
          ),
        );
      },
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }
    return imageWidget;
  }
}
