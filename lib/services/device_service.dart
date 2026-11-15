import 'package:qrscan/config/app_config.dart';
import 'package:qrscan/models/device_model.dart';
import 'package:qrscan/models/paged.dart';
import 'package:qrscan/services/api_client.dart';
import 'package:qrscan/services/api_exception.dart';

abstract class DeviceService {
  /// Resolves scanned or typed text to a device. [raw] is sent unchanged
  /// (after trimming); the server understands full sticker URLs.
  Future<DeviceModel> lookup(String raw);

  Future<Paged<DeviceModel>> list({
    String? search,
    int? tipeId,
    int? categoryDanaId,
    bool? isActive,
    int page = 1,
    int perPage = AppConfig.perPage,
  });

  Future<DeviceModel> getById(int id);
}

class HttpDeviceService implements DeviceService {
  HttpDeviceService(this._api);

  final ApiClient _api;

  static const int maxCodeLength = 500;
  static const int maxSearchLength = 100;

  @override
  Future<DeviceModel> lookup(String raw) async {
    final code = raw.trim();
    if (code.isEmpty || code.length > maxCodeLength) {
      throw const ApiException(ApiFailure.validation, 'Kode tidak valid.');
    }
    final json = await _api.getJson('/devices/lookup', query: {'code': code});
    return _single(json);
  }

  @override
  Future<Paged<DeviceModel>> list({
    String? search,
    int? tipeId,
    int? categoryDanaId,
    bool? isActive,
    int page = 1,
    int perPage = AppConfig.perPage,
  }) async {
    final query = <String, String>{'page': '$page', 'per_page': '$perPage'};
    final term = search?.trim();
    if (term != null && term.isNotEmpty) {
      query['search'] = term.length > maxSearchLength
          ? term.substring(0, maxSearchLength)
          : term;
    }
    if (tipeId != null) query['tipe_id'] = '$tipeId';
    if (categoryDanaId != null) query['category_dana_id'] = '$categoryDanaId';
    // Laravel's boolean rule rejects the strings "true"/"false".
    if (isActive != null) query['is_active'] = isActive ? '1' : '0';

    final json = await _api.getJson('/devices', query: query);
    if (json is! Map) throw _unexpected();
    return Paged.fromJson(
      Map<String, dynamic>.from(json),
      DeviceModel.fromJson,
    );
  }

  @override
  Future<DeviceModel> getById(int id) async {
    final json = await _api.getJson('/devices/$id');
    return _single(json);
  }

  DeviceModel _single(dynamic json) {
    if (json is! Map) throw _unexpected();
    final data = json['data'];
    if (data is! Map || data['id'] is! num) throw _unexpected();
    return DeviceModel.fromJson(Map<String, dynamic>.from(data));
  }

  ApiException _unexpected() =>
      const ApiException(ApiFailure.unknown, 'Terjadi kesalahan. Coba lagi.');
}
