import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qrscan/models/gedung_model.dart';
import 'package:qrscan/models/ref_item.dart';
import 'package:qrscan/services/api_client.dart';

class ReferenceData {
  const ReferenceData({
    required this.gedung,
    required this.tipe,
    required this.categoryDana,
    required this.fetchedAt,
  });

  final List<Gedung> gedung;
  final List<RefItem> tipe;
  final List<RefItem> categoryDana;
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() => {
    'fetched_at': fetchedAt.toIso8601String(),
    'gedung': gedung.map((g) => g.toJson()).toList(),
    'tipe': tipe.map((t) => t.toJson()).toList(),
    'category_dana': categoryDana.map((c) => c.toJson()).toList(),
  };

  static ReferenceData? fromJson(dynamic json) {
    if (json is! Map) return null;
    final fetchedAt = DateTime.tryParse(json['fetched_at']?.toString() ?? '');
    if (fetchedAt == null) return null;
    return ReferenceData(
      gedung: Gedung.listFromJson(json['gedung']),
      tipe: RefItem.listFromJson(json['tipe']),
      categoryDana: RefItem.listFromJson(json['category_dana']),
      fetchedAt: fetchedAt,
    );
  }
}

abstract class ReferenceCache {
  Future<ReferenceData?> read();
  Future<void> write(ReferenceData data);
}

/// Stores the reference lists as a JSON file in the app documents directory.
class FileReferenceCache implements ReferenceCache {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'reference_cache.json'));
  }

  @override
  Future<ReferenceData?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      return ReferenceData.fromJson(jsonDecode(await file.readAsString()));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(ReferenceData data) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(data.toJson()), flush: true);
    } catch (_) {
      debugPrint('ReferenceRepository: cache write failed');
    }
  }
}

class ReferenceRepository extends ChangeNotifier {
  ReferenceRepository({
    required ApiClient api,
    ReferenceCache? cache,
    DateTime Function()? now,
    this.maxAge = const Duration(hours: 24),
  }) : _api = api,
       _cache = cache ?? FileReferenceCache(),
       _now = now ?? DateTime.now;

  final ApiClient _api;
  final ReferenceCache _cache;
  final DateTime Function() _now;
  final Duration maxAge;

  ReferenceData? _data;
  GedungTree? _tree;
  ReferenceData? _treeSource;
  Future<void>? _inFlight;
  bool _isLoading = false;
  Object? _lastError;
  bool _disposed = false;

  ReferenceData? get data => _data;
  bool get isLoading => _isLoading;
  Object? get lastError => _lastError;

  List<Gedung> get gedung => _data?.gedung ?? const [];
  List<RefItem> get tipe => _data?.tipe ?? const [];
  List<RefItem> get categoryDana => _data?.categoryDana ?? const [];

  GedungTree get tree {
    final d = _data;
    if (d == null) return GedungTree.empty;
    if (_tree == null || !identical(_treeSource, d)) {
      _tree = GedungTree.build(d.gedung);
      _treeSource = d;
    }
    return _tree!;
  }

  /// Loads the cache, then refreshes from the server when [force] is set or
  /// the cache is missing or older than [maxAge]. With a cache present a
  /// failed refresh is swallowed (see [lastError]); without one it rethrows.
  Future<void> load({bool force = false}) {
    final running = _inFlight;
    if (running != null) return running;
    final future = _load(force).whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<void> _load(bool force) async {
    if (_data == null) {
      final cached = await _cache.read();
      if (cached != null && _data == null) {
        _data = cached;
        _notify();
      }
    }

    final current = _data;
    final stale =
        current == null || _now().difference(current.fetchedAt) > maxAge;
    if (!force && !stale) return;

    _isLoading = true;
    _lastError = null;
    _notify();
    try {
      final results = await Future.wait([
        _api.getJson('/gedung'),
        _api.getJson('/tipe'),
        _api.getJson('/category-dana'),
      ]);
      List<dynamic>? listOf(dynamic json) =>
          json is Map && json['data'] is List ? json['data'] as List : null;
      final fresh = ReferenceData(
        gedung: Gedung.listFromJson(listOf(results[0])),
        tipe: RefItem.listFromJson(listOf(results[1])),
        categoryDana: RefItem.listFromJson(listOf(results[2])),
        fetchedAt: _now(),
      );
      _data = fresh;
      await _cache.write(fresh);
    } catch (e) {
      _lastError = e;
      if (_data == null) rethrow;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
