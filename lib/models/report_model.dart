import 'package:qrscan/utils/formatters.dart';

class ReportImage {
  const ReportImage({required this.id, required this.url, required this.sort});

  final int id;
  final String url;
  final int sort;

  factory ReportImage.fromJson(Map<String, dynamic> json) => ReportImage(
    id: (json['id'] as num).toInt(),
    url: json['url']?.toString() ?? '',
    sort: (json['sort'] as num?)?.toInt() ?? 0,
  );

  static List<ReportImage> listFromJson(dynamic json) {
    if (json is! List) return const [];
    final result = <ReportImage>[];
    for (final e in json) {
      if (e is Map && e['id'] is num) {
        result.add(ReportImage.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return result;
  }
}

class ReportDeviceRef {
  const ReportDeviceRef({required this.id, required this.code});

  final int id;
  final String code;
}

class ReportGedungRef {
  const ReportGedungRef({
    required this.id,
    required this.name,
    required this.label,
  });

  final int id;
  final String name;
  final String label;
}

class ReportUserRef {
  const ReportUserRef({required this.id, required this.name});

  final int id;
  final String name;
}

class DeviceReport {
  const DeviceReport({
    required this.id,
    required this.uuid,
    required this.deviceId,
    required this.capturedAt,
    required this.createdAt,
    required this.updatedAt,
    this.gedungId,
    this.latitude,
    this.longitude,
    this.notes,
    this.device,
    this.gedung,
    this.user,
    this.images = const [],
  });

  final int id;
  final String uuid;
  final int deviceId;
  final int? gedungId;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ReportDeviceRef? device;
  final ReportGedungRef? gedung;
  final ReportUserRef? user;
  final List<ReportImage> images;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory DeviceReport.fromJson(Map<String, dynamic> json) {
    DateTime date(String key) =>
        DateTime.tryParse(json[key]?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final device = json['device'];
    final gedung = json['gedung'];
    final user = json['user'];
    return DeviceReport(
      id: (json['id'] as num).toInt(),
      uuid: json['uuid']?.toString() ?? '',
      deviceId: (json['device_id'] as num?)?.toInt() ?? 0,
      gedungId: (json['gedung_id'] as num?)?.toInt(),
      capturedAt: date('captured_at'),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      notes: json['notes']?.toString(),
      createdAt: date('created_at'),
      updatedAt: date('updated_at'),
      device: device is Map
          ? ReportDeviceRef(
              id: (device['id'] as num).toInt(),
              code: device['code']?.toString() ?? '',
            )
          : null,
      gedung: gedung is Map
          ? ReportGedungRef(
              id: (gedung['id'] as num).toInt(),
              name: gedung['name']?.toString() ?? '',
              label:
                  gedung['label']?.toString() ??
                  gedung['name']?.toString() ??
                  '',
            )
          : null,
      user: user is Map
          ? ReportUserRef(
              id: (user['id'] as num).toInt(),
              name: user['name']?.toString() ?? '',
            )
          : null,
      images: ReportImage.listFromJson(json['images']),
    );
  }
}

class ReportFilter {
  const ReportFilter({
    this.deviceId,
    this.gedungId,
    this.userId,
    this.from,
    this.to,
    this.q,
  });

  final int? deviceId;
  final int? gedungId;
  final int? userId;
  final DateTime? from;
  final DateTime? to;
  final String? q;

  bool get isEmpty =>
      deviceId == null &&
      gedungId == null &&
      userId == null &&
      from == null &&
      to == null &&
      (q == null || q!.trim().isEmpty);

  /// Query parameters for `GET /device-reports` (without paging).
  Map<String, String> toQuery() {
    final query = <String, String>{};
    if (deviceId != null) query['device_id'] = '$deviceId';
    if (gedungId != null) query['gedung_id'] = '$gedungId';
    if (userId != null) query['user_id'] = '$userId';
    if (from != null) query['from'] = formatDate(from!);
    if (to != null) query['to'] = formatDate(to!);
    final search = q?.trim();
    if (search != null && search.isNotEmpty) {
      query['q'] = search.length > 100 ? search.substring(0, 100) : search;
    }
    return query;
  }

  /// Fields passed as `null` keep their value. Use the `clear*` flags to
  /// remove a field.
  ReportFilter copyWith({
    int? deviceId,
    int? gedungId,
    int? userId,
    DateTime? from,
    DateTime? to,
    String? q,
    bool clearDeviceId = false,
    bool clearGedungId = false,
    bool clearUserId = false,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearQ = false,
  }) {
    return ReportFilter(
      deviceId: clearDeviceId ? null : (deviceId ?? this.deviceId),
      gedungId: clearGedungId ? null : (gedungId ?? this.gedungId),
      userId: clearUserId ? null : (userId ?? this.userId),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      q: clearQ ? null : (q ?? this.q),
    );
  }
}
