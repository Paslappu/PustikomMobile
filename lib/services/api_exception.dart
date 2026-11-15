enum ApiFailure {
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  tooLarge,
  rateLimited,
  server,
  network,
  timeout,
  unknown,
}

class ApiException implements Exception {
  const ApiException(
    this.failure,
    this.message, {
    this.status,
    this.fieldErrors = const {},
    this.retryAfter,
  });

  final ApiFailure failure;
  final int? status;
  final String message;
  final Map<String, List<String>> fieldErrors;
  final Duration? retryAfter;

  static const String unauthorizedMessage =
      'Sesi berakhir. Silakan masuk kembali.';
  static const String networkMessage =
      'Tidak dapat terhubung ke server. Periksa koneksi Anda.';
  static const String timeoutMessage =
      'Koneksi ke server terlalu lama. Coba lagi.';

  const ApiException.network() : this(ApiFailure.network, networkMessage);

  const ApiException.timeout() : this(ApiFailure.timeout, timeoutMessage);

  /// Builds an exception from an HTTP error response. [json] may be null when
  /// the body was empty or not JSON (for example an HTML 413 page).
  factory ApiException.fromResponse(
    int status,
    dynamic json, {
    Duration? retryAfter,
  }) {
    final fieldErrors = _parseErrors(json);
    String? firstAny;
    for (final list in fieldErrors.values) {
      if (list.isNotEmpty) {
        firstAny = list.first;
        break;
      }
    }

    switch (status) {
      case 401:
        return ApiException(
          ApiFailure.unauthorized,
          unauthorizedMessage,
          status: status,
        );
      case 403:
        return ApiException(
          ApiFailure.forbidden,
          'Anda tidak memiliki akses.',
          status: status,
        );
      case 404:
        return ApiException(
          ApiFailure.notFound,
          'Data tidak ditemukan.',
          status: status,
        );
      case 409:
        return ApiException(
          ApiFailure.conflict,
          'ID laporan sudah dipakai pengguna lain.',
          status: status,
        );
      case 413:
        return ApiException(
          ApiFailure.tooLarge,
          'Ukuran unggahan melebihi batas server. '
          'Kurangi jumlah atau ukuran foto.',
          status: status,
        );
      case 422:
        final serverMessage = json is Map && json['message'] is String
            ? json['message'] as String
            : null;
        return ApiException(
          ApiFailure.validation,
          firstAny ?? serverMessage ?? 'Data yang dikirim tidak valid.',
          status: status,
          fieldErrors: fieldErrors,
        );
      case 429:
        return ApiException(
          ApiFailure.rateLimited,
          'Terlalu banyak percobaan. Coba lagi sebentar.',
          status: status,
          retryAfter: retryAfter,
        );
    }
    if (status >= 500) {
      return ApiException(
        ApiFailure.server,
        'Server sedang bermasalah. Coba lagi nanti.',
        status: status,
      );
    }
    return ApiException(
      ApiFailure.unknown,
      'Terjadi kesalahan. Coba lagi.',
      status: status,
    );
  }

  static Map<String, List<String>> _parseErrors(dynamic json) {
    if (json is! Map) return const {};
    final errors = json['errors'];
    if (errors is! Map) return const {};
    final result = <String, List<String>>{};
    errors.forEach((key, value) {
      if (value is List) {
        result[key.toString()] = value.map((e) => e.toString()).toList();
      } else if (value != null) {
        result[key.toString()] = [value.toString()];
      }
    });
    return result;
  }

  String? firstError(String key) {
    final list = fieldErrors[key];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  String? get firstAnyError {
    for (final list in fieldErrors.values) {
      if (list.isNotEmpty) return list.first;
    }
    return null;
  }

  bool get isTransient =>
      failure == ApiFailure.network ||
      failure == ApiFailure.timeout ||
      failure == ApiFailure.server ||
      failure == ApiFailure.rateLimited;

  @override
  String toString() => message;
}
