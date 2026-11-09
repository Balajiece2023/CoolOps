import 'package:flutter/material.dart';

/// Central branding and customizable asset configuration.
class AppBranding {
  // Brand Names & Tagline
  static const String appName = 'Caring Cool Tech';
  static const String appTagline = 'Air Conditioning & HVAC Service Operations';
  static const String companyName = 'CARING COOL TECH';
  static const String address = 'GR FL NO.1NETHA NAGAR VALARAMPET PUDUCHERRY-605 004';
  static const String supportPhone = '9677686561';
  static const String supportEmail = 'caringcooltech@gmail.com';
  static const String gstin = '34BYEPA2853E1ZX';
  static const String state = '34-Puducherry';

  // Bank Details
  static const String bankName = 'CITY UNION BANK 93 VILLIANUR ROAD,REDDIARPALAYAM';
  static const String bankAccountNo = '510909010146288';
  static const String bankIfsc = 'CIUB0000421';
  static const String bankHolder = 'CARING COOL TECH';

  // Asset Paths
  static const String appLogo = 'assets/images/cct_logo.png';
  static const String appIcon = 'assets/images/cct_logo.png';

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
            color: const Color(0xFF1E75BB).withValues(alpha: 0.1),
            borderRadius: borderRadius ?? BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.ac_unit, color: Color(0xFF1E75BB), size: 32),
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
