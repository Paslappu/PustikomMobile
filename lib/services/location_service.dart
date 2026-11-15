import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum LocationIssue { serviceDisabled, denied, deniedForever, timeout, error }

class LocationFix {
  const LocationFix({
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.issue,
  });

  const LocationFix.failed(LocationIssue this.issue)
    : latitude = null,
      longitude = null,
      accuracyMeters = null;

  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final LocationIssue? issue;

  bool get ok => latitude != null && longitude != null;
}

/// A raw position from the platform.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude, this.accuracyMeters);

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
}

/// Thin wrapper over the geolocator plugin so tests can fake it.
abstract class LocationGateway {
  Future<bool> isServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();

  /// Throws [TimeoutException] when no fix arrives within [timeLimit].
  Future<GeoPoint> currentPosition({required Duration timeLimit});
  Future<GeoPoint?> lastKnownPosition();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class GeolocatorGateway implements LocationGateway {
  const GeolocatorGateway();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<GeoPoint> currentPosition({required Duration timeLimit}) async {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeLimit,
      ),
    );
    return GeoPoint(p.latitude, p.longitude, p.accuracy);
  }

  @override
  Future<GeoPoint?> lastKnownPosition() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p == null) return null;
      return GeoPoint(p.latitude, p.longitude, p.accuracy);
    } catch (_) {
      // Not supported on every platform.
      return null;
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

class LocationService {
  LocationService([LocationGateway? gateway])
    : _gateway = gateway ?? const GeolocatorGateway();

  final LocationGateway _gateway;

  static const Duration fixTimeout = Duration(seconds: 15);

  /// Asks for permission when needed and returns a GPS fix or the reason there
  /// is none. Never throws and never logs coordinates.
  Future<LocationFix> capture() async {
    try {
      if (!await _gateway.isServiceEnabled()) {
        return const LocationFix.failed(LocationIssue.serviceDisabled);
      }

      var permission = await _gateway.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _gateway.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationFix.failed(LocationIssue.deniedForever);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return const LocationFix.failed(LocationIssue.denied);
      }

      try {
        final p = await _gateway.currentPosition(timeLimit: fixTimeout);
        return _fix(p);
      } on TimeoutException {
        final last = await _gateway.lastKnownPosition();
        if (last != null) return _fix(last);
        return const LocationFix.failed(LocationIssue.timeout);
      }
    } catch (_) {
      return const LocationFix.failed(LocationIssue.error);
    }
  }

  Future<bool> openAppSettings() => _gateway.openAppSettings();

  Future<bool> openLocationSettings() => _gateway.openLocationSettings();

  LocationFix _fix(GeoPoint p) => LocationFix(
    latitude: p.latitude,
    longitude: p.longitude,
    accuracyMeters: p.accuracyMeters,
  );
}
