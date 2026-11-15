import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:qrscan/config/app_config.dart';
import 'package:qrscan/models/outbox_item.dart';
import 'package:qrscan/models/paged.dart';
import 'package:qrscan/models/report_model.dart';
import 'package:qrscan/services/api_client.dart';
import 'package:qrscan/services/api_exception.dart';
import 'package:qrscan/utils/formatters.dart';

class CreateResult {
  const CreateResult({required this.report, required this.createdNew});

  final DeviceReport report;

  /// True for 201 (new report), false for 200 (an earlier retry with the same
  /// uuid already created it).
  final bool createdNew;
}

/// Uploads a queued report. Separate from [ReportService] so the outbox can be
/// tested with a fake.
abstract class ReportSender {
  Future<CreateResult> create(
    OutboxItem item,
    List<File> files, {
    void Function(int sent, int total)? onProgress,
  });
}

/// Partial update for `PATCH /device-reports/{id}`. Only fields flagged as set
/// are sent. `device_id` is never sent.
class ReportPatch {
  const ReportPatch({
    this.capturedAt,
    this.setGedung = false,
    this.gedungId,
    this.setCoords = false,
    this.latitude,
    this.longitude,
    this.setNotes = false,
    this.notes,
  });

  final DateTime? capturedAt;
  final bool setGedung;
  final int? gedungId;

  /// When true both [latitude] and [longitude] are sent (null clears them).
  final bool setCoords;
  final double? latitude;
  final double? longitude;
  final bool setNotes;
  final String? notes;

  bool get isEmpty =>
      capturedAt == null && !setGedung && !setCoords && !setNotes;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (capturedAt != null) {
      json['captured_at'] = formatIsoWithOffset(capturedAt!);
    }
    if (setGedung) json['gedung_id'] = gedungId;
    if (setCoords) {
      json['latitude'] = latitude;
      json['longitude'] = longitude;
    }
    if (setNotes) json['notes'] = notes;
    return json;
  }
}

abstract class ReportService implements ReportSender {
  Future<Paged<DeviceReport>> list(
    ReportFilter filter, {
    int page = 1,
    int perPage = AppConfig.perPage,
  });

  Future<DeviceReport> get(int id);

  Future<DeviceReport> update(int id, ReportPatch patch);

  /// A 404 is treated as success (already deleted).
  Future<void> delete(int id);

  Future<List<ReportImage>> addImages(
    int id,
    List<File> files, {
    void Function(int sent, int total)? onProgress,
  });

  /// A 404 is treated as success (already deleted).
  Future<void> deleteImage(int reportId, int imageId);

  /// Incremented after every successful create, update, delete or image change.
  ValueNotifier<int> get revision;
}

class HttpReportService implements ReportService {
  HttpReportService(this._api);

  final ApiClient _api;

  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void _bump() => revision.value++;

  @override
  Future<CreateResult> create(
    OutboxItem item,
    List<File> files, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final fields = <String, String>{
      'uuid': item.uuid,
      'device_id': '${item.deviceId}',
      'captured_at': item.capturedAt,
    };
    if (item.gedungId != null) fields['gedung_id'] = '${item.gedungId}';
    if (item.latitude != null && item.longitude != null) {
      fields['latitude'] = item.latitude!.toStringAsFixed(7);
      fields['longitude'] = item.longitude!.toStringAsFixed(7);
    }
    final notes = item.notes.trim();
    if (notes.isNotEmpty) fields['notes'] = notes;

    final res = await _api.sendMultipart(
      '/device-reports',
      fields: fields,
      files: files,
      onProgress: onProgress,
    );
    final report = _report(res.json);
    _bump();
    return CreateResult(report: report, createdNew: res.status == 201);
  }

  @override
  Future<Paged<DeviceReport>> list(
    ReportFilter filter, {
    int page = 1,
    int perPage = AppConfig.perPage,
  }) async {
    final query = filter.toQuery()
      ..['page'] = '$page'
      ..['per_page'] = '$perPage';
    final json = await _api.getJson('/device-reports', query: query);
    if (json is! Map) throw _unexpected();
    return Paged.fromJson(
      Map<String, dynamic>.from(json),
      DeviceReport.fromJson,
    );
  }

  @override
  Future<DeviceReport> get(int id) async {
    final json = await _api.getJson('/device-reports/$id');
    return _report(json);
  }

  @override
  Future<DeviceReport> update(int id, ReportPatch patch) async {
    final json = await _api.sendJson(
      'PATCH',
      '/device-reports/$id',
      body: patch.toJson(),
    );
    final report = _report(json);
    _bump();
    return report;
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _api.sendJson('DELETE', '/device-reports/$id');
    } on ApiException catch (e) {
      if (e.failure != ApiFailure.notFound) rethrow;
    }
    _bump();
  }

  @override
  Future<List<ReportImage>> addImages(
    int id,
    List<File> files, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final res = await _api.sendMultipart(
      '/device-reports/$id/images',
      fields: const {},
      files: files,
      onProgress: onProgress,
    );
    final json = res.json;
    final data = json is Map ? json['data'] : null;
    if (data is! List) throw _unexpected();
    _bump();
    return ReportImage.listFromJson(data);
  }

  @override
  Future<void> deleteImage(int reportId, int imageId) async {
    try {
      await _api.sendJson(
        'DELETE',
        '/device-reports/$reportId/images/$imageId',
      );
    } on ApiException catch (e) {
      if (e.failure != ApiFailure.notFound) rethrow;
    }
    _bump();
  }

  DeviceReport _report(dynamic json) {
    if (json is! Map) throw _unexpected();
    final data = json['data'];
    if (data is! Map || data['id'] is! num) throw _unexpected();
    return DeviceReport.fromJson(Map<String, dynamic>.from(data));
  }

  ApiException _unexpected() =>
      const ApiException(ApiFailure.unknown, 'Terjadi kesalahan. Coba lagi.');
}
