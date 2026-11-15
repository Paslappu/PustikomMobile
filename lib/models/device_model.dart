import 'dart:ui' show Offset;

import 'package:qrscan/models/gedung_model.dart';
import 'package:qrscan/models/ref_item.dart';

class DeviceLocation {
  const DeviceLocation({this.gedung, this.location, this.since});

  final Gedung? gedung;

  /// Position on the building image as "x,y" in percent.
  final String? location;
  final DateTime? since;

  factory DeviceLocation.fromJson(Map<String, dynamic> json) {
    final g = json['gedung'];
    return DeviceLocation(
      gedung: g is Map ? Gedung.fromJson(Map<String, dynamic>.from(g)) : null,
      location: json['location']?.toString(),
      since: DateTime.tryParse(json['since']?.toString() ?? ''),
    );
  }

  /// Parsed [location] (x, y in percent) or null when malformed.
  Offset? get percentPoint {
    final raw = location;
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final x = double.tryParse(parts[0].trim());
    final y = double.tryParse(parts[1].trim());
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  /// For example `50.00%, 25.00%`.
  String? get coordinateLabel {
    final p = percentPoint;
    if (p == null) return null;
    return '${p.dx.toStringAsFixed(2)}%, ${p.dy.toStringAsFixed(2)}%';
  }
}

class DeviceModel {
  const DeviceModel({
    required this.id,
    required this.code,
    required this.isActive,
    this.tipe,
    this.categoryDana,
    this.stickerUrl,
    this.currentLocation,
  });

  final int id;
  final String code;
  final bool isActive;
  final RefItem? tipe;
  final RefItem? categoryDana;
  final String? stickerUrl;
  final DeviceLocation? currentLocation;

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    RefItem? ref(dynamic v) =>
        v is Map ? RefItem.fromJson(Map<String, dynamic>.from(v)) : null;
    final loc = json['current_location'];
    final active = json['is_active'];
    return DeviceModel(
      id: (json['id'] as num).toInt(),
      code: json['code']?.toString() ?? '',
      isActive: active is bool ? active : (active == 1 || active == '1'),
      tipe: ref(json['tipe']),
      categoryDana: ref(json['category_dana']),
      stickerUrl: json['sticker_url']?.toString(),
      currentLocation: loc is Map
          ? DeviceLocation.fromJson(Map<String, dynamic>.from(loc))
          : null,
    );
  }

  /// "Tipe - Kategori dana" summary, skipping missing parts.
  String get subtitle => [
    tipe?.name,
    categoryDana?.name,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
}
