import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Centralized real-device GPS Location Service for Caring CoolTech.
/// Provides native phone GPS access with battery-efficient distance filtering.
class LocationService {
  // Default fallback coordinates: Caring CoolTech HQ (Puducherry)
  static const double defaultLatitude = 11.9416;
  static const double defaultLongitude = 79.8083;

  /// Check and request device location permissions.
  /// Returns true if permission is granted, false otherwise.
  static Future<bool> ensureLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] GPS Location services are disabled on device.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Location permissions were denied by user.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permissions are permanently denied.');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[LocationService] Error ensuring permissions: $e');
      return false;
    }
  }

  /// Get current native GPS coordinates from phone.
  /// Falls back to last known position or default HQ if GPS is unavailable.
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await ensureLocationPermission();
      if (!hasPermission) {
        // Attempt last known location before giving up
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) return lastKnown;
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('[LocationService] Failed to get current position: $e');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Create a battery-friendly stream of GPS updates.
  /// Triggers only when phone has moved at least [distanceFilterMeters] (default: 15m).
  static Stream<Position> getPositionStream({int distanceFilterMeters = 15}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    );
  }

  /// Calculate distance between two GPS coordinates in meters.
  static double calculateDistanceInMeters({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Calculate estimated travel time in minutes based on distance and average speed (km/h).
  static int estimateEtaMinutes(double distanceInKm, {double avgSpeedKmh = 25.0}) {
    if (distanceInKm <= 0.1) return 1;
    final hours = distanceInKm / avgSpeedKmh;
    final minutes = (hours * 60).round();
    return minutes < 1 ? 1 : minutes;
  }
}

