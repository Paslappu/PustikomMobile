import 'dart:convert';

enum OutboxStatus { draft, pending, uploading, waiting, failed, sent }

class OutboxImage {
  const OutboxImage({
    this.id,
    required this.relPath,
    required this.sizeBytes,
    required this.position,
  });

  final int? id;

  /// Path relative to the outbox root (`<uuid>/<name>.jpg`).
  final String relPath;
  final int sizeBytes;
  final int position;

  factory OutboxImage.fromMap(Map<String, Object?> map) => OutboxImage(
    id: map['id'] as int?,
    relPath: map['rel_path'] as String? ?? '',
    sizeBytes: (map['size_bytes'] as num?)?.toInt() ?? 0,
    position: (map['position'] as num?)?.toInt() ?? 0,
  );

  /// Columns for `report_outbox_image`. The `id` column is auto-assigned.
  Map<String, Object?> toMap(String outboxUuid) => {
    'outbox_uuid': outboxUuid,
    'position': position,
    'rel_path': relPath,
    'size_bytes': sizeBytes,
  };
}

class OutboxItem {
  const OutboxItem({
    required this.uuid,
    required this.userId,
    required this.deviceId,
    required this.deviceCode,
    required this.deviceLabel,
    required this.capturedAt,
    required this.createdAt,
    required this.updatedAt,
    this.gedungId,
    this.gedungLabel,
    this.latitude,
    this.longitude,
    this.notes = '',
    this.status = OutboxStatus.draft,
    this.attempts = 0,
    this.nextAttemptAt = 0,
    this.lastError,
    this.lastErrorCode,
    this.fieldErrors = const {},
    this.sentReportId,
    this.sentAt,
    this.images = const [],
  });

  final String uuid;
  final int userId;
  final int deviceId;
  final String deviceCode;
  final String deviceLabel;
  final int? gedungId;
  final String? gedungLabel;

  /// ISO 8601 with the local UTC offset, stamped when the draft was created.
  final String capturedAt;
  final double? latitude;
  final double? longitude;
  final String notes;
  final OutboxStatus status;
  final int attempts;

  /// Epoch milliseconds.
  final int nextAttemptAt;
  final String? lastError;
  final int? lastErrorCode;
  final Map<String, List<String>> fieldErrors;
  final int createdAt;
  final int updatedAt;
  final int? sentReportId;
  final int? sentAt;
  final List<OutboxImage> images;

  bool get hasCoordinates => latitude != null && longitude != null;

  Map<String, Object?> toMap() => {
    'uuid': uuid,
    'user_id': userId,
    'device_id': deviceId,
    'device_code': deviceCode,
    'device_label': deviceLabel,
    'gedung_id': gedungId,
    'gedung_label': gedungLabel,
    'captured_at': capturedAt,
    'latitude': latitude,
    'longitude': longitude,
    'notes': notes,
    'status': status.name,
    'attempts': attempts,
    'next_attempt_at': nextAttemptAt,
    'last_error': lastError,
    'last_error_code': lastErrorCode,
    'field_errors': fieldErrors.isEmpty ? null : jsonEncode(fieldErrors),
    'created_at': createdAt,
    'updated_at': updatedAt,
    'sent_report_id': sentReportId,
    'sent_at': sentAt,
  };

  factory OutboxItem.fromMap(
    Map<String, Object?> map, {
    List<OutboxImage> images = const [],
  }) {
    return OutboxItem(
      uuid: map['uuid'] as String,
      userId: (map['user_id'] as num?)?.toInt() ?? 0,
      deviceId: (map['device_id'] as num?)?.toInt() ?? 0,
      deviceCode: map['device_code'] as String? ?? '',
      deviceLabel: map['device_label'] as String? ?? '',
      gedungId: (map['gedung_id'] as num?)?.toInt(),
      gedungLabel: map['gedung_label'] as String?,
      capturedAt: map['captured_at'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      notes: map['notes'] as String? ?? '',
      status: _statusFrom(map['status'] as String?),
      attempts: (map['attempts'] as num?)?.toInt() ?? 0,
      nextAttemptAt: (map['next_attempt_at'] as num?)?.toInt() ?? 0,
      lastError: map['last_error'] as String?,
      lastErrorCode: (map['last_error_code'] as num?)?.toInt(),
      fieldErrors: _decodeFieldErrors(map['field_errors'] as String?),
      createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (map['updated_at'] as num?)?.toInt() ?? 0,
      sentReportId: (map['sent_report_id'] as num?)?.toInt(),
      sentAt: (map['sent_at'] as num?)?.toInt(),
      images: images,
    );
  }

  static OutboxStatus _statusFrom(String? name) {
    for (final s in OutboxStatus.values) {
      if (s.name == name) return s;
    }
    return OutboxStatus.failed;
  }

  static Map<String, List<String>> _decodeFieldErrors(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final e in decoded.entries)
          e.key.toString(): e.value is List
              ? (e.value as List).map((v) => v.toString()).toList()
              : <String>[e.value.toString()],
      };
    } catch (_) {
      return const {};
    }
  }

  /// Nullable fields can be cleared with the matching `clear*` flag, because a
  /// `null` argument means "keep".
  OutboxItem copyWith({
    int? gedungId,
    String? gedungLabel,
    bool clearGedung = false,
    String? capturedAt,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
    String? notes,
    OutboxStatus? status,
    int? attempts,
    int? nextAttemptAt,
    String? lastError,
    int? lastErrorCode,
    bool clearError = false,
    Map<String, List<String>>? fieldErrors,
    int? updatedAt,
    int? sentReportId,
    int? sentAt,
    List<OutboxImage>? images,
  }) {
    return OutboxItem(
      uuid: uuid,
      userId: userId,
      deviceId: deviceId,
      deviceCode: deviceCode,
      deviceLabel: deviceLabel,
      gedungId: clearGedung ? null : (gedungId ?? this.gedungId),
      gedungLabel: clearGedung ? null : (gedungLabel ?? this.gedungLabel),
      capturedAt: capturedAt ?? this.capturedAt,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      notes: notes ?? this.notes,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastErrorCode: clearError ? null : (lastErrorCode ?? this.lastErrorCode),
      fieldErrors: clearError ? const {} : (fieldErrors ?? this.fieldErrors),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sentReportId: sentReportId ?? this.sentReportId,
      sentAt: sentAt ?? this.sentAt,
      images: images ?? this.images,
    );
  }
}
