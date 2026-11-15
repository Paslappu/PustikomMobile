import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:qrscan/config/app_config.dart';
import 'package:qrscan/services/api_exception.dart';
import 'package:qrscan/services/multipart_progress.dart';

class ApiResponse {
  const ApiResponse(this.status, this.json);

  final int status;

  /// Decoded body. Null for empty or non-JSON bodies (204, HTML, ...).
  final dynamic json;
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl, this.tokenReader})
    : _client = client ?? http.Client(),
      _baseUrl = _trimSlash(baseUrl ?? AppConfig.apiBaseUrl);

  final http.Client _client;
  final String _baseUrl;

  /// Supplies the current bearer token. Set by the auth layer.
  String? Function()? tokenReader;

  /// Called once per request that came back 401 with `auth: true`. Receives
  /// the token that was used so the owner can ignore stale responses.
  void Function(String? tokenUsed)? onUnauthorized;

  static String _trimSlash(String s) =>
      s.endsWith('/') ? s.substring(0, s.length - 1) : s;

  Uri _uri(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$p');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final req = http.Request('GET', _uri(path, query));
    final res = await _dispatch(
      req,
      auth: auth,
      timeout: AppConfig.requestTimeout,
    );
    return res.json;
  }

  /// POST, PATCH or DELETE with an optional JSON [body].
  Future<dynamic> sendJson(
    String method,
    String path, {
    Object? body,
    bool auth = true,
    Duration? timeout,
    String? tokenOverride,
  }) async {
    final req = http.Request(method, _uri(path));
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final res = await _dispatch(
      req,
      auth: auth,
      timeout: timeout ?? AppConfig.requestTimeout,
      tokenOverride: tokenOverride,
    );
    return res.json;
  }

  Future<ApiResponse> sendMultipart(
    String path, {
    required Map<String, String> fields,
    required List<File> files,
    String fileField = 'images[]',
    void Function(int sent, int total)? onProgress,
    Duration? timeout,
  }) async {
    final abort = Completer<void>();
    final req = ProgressMultipartRequest(
      'POST',
      _uri(path),
      onProgress: onProgress,
      abortTrigger: abort.future,
    );
    req.fields.addAll(fields);
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      req.files.add(
        http.MultipartFile(
          fileField,
          http.ByteStream(file.openRead()),
          await file.length(),
          filename: 'foto_${i + 1}.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    }
    return _dispatch(
      req,
      auth: true,
      timeout: timeout ?? AppConfig.uploadTimeout,
      onTimeout: () {
        if (!abort.isCompleted) abort.complete();
      },
    );
  }

  Future<ApiResponse> _dispatch(
    http.BaseRequest req, {
    required bool auth,
    required Duration timeout,
    void Function()? onTimeout,
    String? tokenOverride,
  }) async {
    final token = auth ? (tokenOverride ?? tokenReader?.call()) : null;
    req.headers['Accept'] = 'application/json';
    if (auth && token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }

    final http.Response res;
    try {
      res = await (() async {
        final streamed = await _client.send(req);
        return http.Response.fromStream(streamed);
      })().timeout(timeout);
    } on TimeoutException {
      onTimeout?.call();
      throw const ApiException.timeout();
    } on SocketException {
      throw const ApiException.network();
    } on HandshakeException {
      throw const ApiException.network();
    } on http.ClientException {
      throw const ApiException.network();
    }

    final json = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return ApiResponse(res.statusCode, json);
    }

    final retryAfter = _parseRetryAfter(res.headers['retry-after']);
    final error = ApiException.fromResponse(
      res.statusCode,
      json,
      retryAfter: retryAfter,
    );
    if (res.statusCode == 401 && auth) {
      onUnauthorized?.call(token);
    }
    throw error;
  }

  static dynamic _decode(http.Response res) {
    if (res.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  static Duration? _parseRetryAfter(String? header) {
    if (header == null) return null;
    final seconds = int.tryParse(header.trim());
    if (seconds == null || seconds < 0) return null;
    return Duration(seconds: seconds);
  }

  void dispose() => _client.close();
}
