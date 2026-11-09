import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    required this.name,
    this.radius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatarChild;

    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';

    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      final url = avatarUrl!.trim();
      if (url.startsWith('data:image')) {
        try {
          final commaIndex = url.indexOf(',');
          final base64Str = commaIndex != -1 ? url.substring(commaIndex + 1) : url;
          final Uint8List bytes = base64Decode(base64Str);
          avatarChild = CircleAvatar(
            radius: radius,
            backgroundImage: MemoryImage(bytes),
          );
        } catch (_) {
          avatarChild = _buildFallback(initial);
        }
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        avatarChild = CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: NetworkImage(url),
          onBackgroundImageError: (_, __) {},
          child: null,
        );
      } else {
        avatarChild = _buildFallback(initial);
      }
    } else {
      avatarChild = _buildFallback(initial);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarChild,
      );
    }

    return avatarChild;
  }

  Widget _buildFallback(String initial) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primaryBlue.withOpacity(0.18),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.75,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryBlue,
        ),
      ),
    );
  }
}

