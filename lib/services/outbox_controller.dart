import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:qrscan/models/outbox_item.dart';
import 'package:qrscan/services/api_exception.dart';
import 'package:qrscan/services/outbox_files.dart';
import 'package:qrscan/services/outbox_store.dart';
import 'package:qrscan/services/report_service.dart';
import 'package:qrscan/utils/formatters.dart';
import 'package:uuid/uuid.dart';

class OutboxPolicy {
  const OutboxPolicy({
    this.baseDelay = const Duration(seconds: 15),
    this.maxDelay = const Duration(minutes: 15),
    this.maxAttempts = 8,
    this.maxAge = const Duration(days: 7),
    this.sentRetention = const Duration(days: 7),
    this.draftRetention = const Duration(days: 7),
    this.uploadStale = const Duration(minutes: 5),
    this.orphanAge = const Duration(days: 1),
    this.emptyDraftAge = const Duration(hours: 1),
  });

  final Duration baseDelay;
  final Duration maxDelay;
  final int maxAttempts;

  /// A queued report older than this is no longer retried automatically.
  final Duration maxAge;
  final Duration sentRetention;
  final Duration draftRetention;
  final Duration uploadStale;

  /// Photo folders without a database row are deleted after this age.
  final Duration orphanAge;

  /// An empty draft is dropped at sign-in only after this age, so a photo
  /// recovered after an Android activity kill still finds its draft.
  final Duration emptyDraftAge;
}

/// Offline queue for new device reports.
///
/// Reports are created as drafts, uploaded one at a time and retried with the
/// same uuid, so the server never creates duplicates. Only items of the
/// attached user are listed or sent.
class OutboxController extends ChangeNotifier {
  OutboxController({
    required this.store,
    required ReportSender sender,
    required this.files,
    this.policy = const OutboxPolicy(),
    DateTime Function()? now,
    Random? random,
    Uuid? uuid,
  }) : _sender = sender,
       _now = now ?? DateTime.now,
       _random = random ?? Random(),
       _uuid = uuid ?? const Uuid();

  final OutboxStore store;
  final OutboxFiles files;
  final OutboxPolicy policy;
  final ReportSender _sender;
  final DateTime Function() _now;
  final Random _random;
  final Uuid _uuid;

  /// Upload progress per uuid (0..1). Not persisted.
  final ValueNotifier<Map<String, double>> progress = ValueNotifier(const {});

  int? _userId;
  int _generation = 0;
  List<OutboxItem> _items = const [];
  bool _blockedByAuth = false;
  bool _paused = false;
  bool _disposed = false;
  Timer? _timer;
  Future<void>? _draining;
  Future<void> _tail = Future<void>.value();
  String? _inFlightUuid;

  static const _kErrorRepeated = 'Gagal berulang. Tekan Coba lagi.';
  static const _kErrorFiles =
      'Foto hilang atau tidak valid. Perbaiki laporan atau hapus.';

  /// Items of the current user, oldest first.
  List<OutboxItem> get items => List.unmodifiable(_items);

  List<OutboxItem> get drafts =>
      _items.where((i) => i.status == OutboxStatus.draft).toList();

  /// pending + uploading + waiting + failed.
  int get badgeCount => _items.where((i) => _counts(i.status)).length;

  /// True after a 401: sending is paused until the user signs in again.
  bool get blockedByAuth => _blockedByAuth;

  bool _counts(OutboxStatus s) =>
      s == OutboxStatus.pending ||
      s == OutboxStatus.uploading ||
      s == OutboxStatus.waiting ||
      s == OutboxStatus.failed;

  // ---- Lifecycle ----

  /// Starts the queue for [userId]: loads items, recovers from a crash, purges
  /// old rows and sends whatever is due.
  Future<void> attach(int userId) async {
    _generation++;
    _userId = userId;
    _blockedByAuth = false;
    _paused = false;
    final gen = _generation;

    await store.resetUploadingToPending();
    var loaded = await store.listForUser(userId);
    loaded = await _purge(loaded);
    if (_disposed || gen != _generation) return;
    _items = loaded;
    _notify();

    unawaited(drain());
    _armTimer();
  }

  /// Sign-out: stops sending and clears the in-memory list. Rows and photos
  /// stay on disk for the next sign-in of the same user.
  void detach() {
    _generation++;
    _userId = null;
    _timer?.cancel();
    _timer = null;
    _items = const [];
    progress.value = const {};
    _notify();
  }

  void onResumed() {
    _paused = false;
    if (_userId == null) return;
    unawaited(_resumeWork());
  }

  void onPaused() {
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _resumeWork() async {
    if (_draining == null && _inFlightUuid == null) {
      final cutoff =
          _now().millisecondsSinceEpoch - policy.uploadStale.inMilliseconds;
      for (final item in List.of(_items)) {
        if (item.status == OutboxStatus.uploading && item.updatedAt < cutoff) {
          await _put(
            item.copyWith(status: OutboxStatus.pending, updatedAt: _ms),
          );
        }
      }
    }
    await drain();
    _armTimer();
  }

  Future<List<OutboxItem>> _purge(List<OutboxItem> loaded) async {
    final nowMs = _ms;
    final keep = <OutboxItem>[];
    for (final item in loaded) {
      final age = Duration(milliseconds: nowMs - max(item.createdAt, 0));
      var drop = false;
      switch (item.status) {
        case OutboxStatus.sent:
          final sentAt = item.sentAt ?? item.updatedAt;
          drop = nowMs - sentAt > policy.sentRetention.inMilliseconds;
        case OutboxStatus.draft:
          final empty = item.images.isEmpty && item.notes.trim().isEmpty;
          drop =
              (empty && age > policy.emptyDraftAge) ||
              age > policy.draftRetention;
        default:
          break;
      }
      if (drop) {
        await store.delete(item.uuid);
        await files.deleteDir(item.uuid);
      } else {
        keep.add(item);
      }
    }
    await files.purgeOrphans(await store.allUuids(), policy.orphanAge);
    return keep;
  }

  // ---- Drafts ----

  Future<OutboxItem> beginDraft({
    required int deviceId,
    required String deviceCode,
    required String deviceLabel,
  }) async {
    final userId = _requireUser();
    final now = _now();
    final item = OutboxItem(
      uuid: _uuid.v4().toLowerCase(),
      userId: userId,
      deviceId: deviceId,
      deviceCode: deviceCode,
      deviceLabel: deviceLabel,
      capturedAt: formatIsoWithOffset(now),
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    );
    await store.insert(item);
    files.draftDir(item.uuid);
    _setInMemory(item);
    return item;
  }

  /// Persists the editable fields of [item] (gedung, notes, coordinates,
  /// captured time). Status and photos are kept as they are. Ignored while the
  /// item is queued or uploading.
  Future<OutboxItem> saveDraft(OutboxItem item) async {
    final cur = _require(item.uuid);
    if (!_editable(cur.status)) return cur;
    final next = OutboxItem(
      uuid: cur.uuid,
      userId: cur.userId,
      deviceId: cur.deviceId,
      deviceCode: cur.deviceCode,
      deviceLabel: cur.deviceLabel,
      gedungId: item.gedungId,
      gedungLabel: item.gedungLabel,
      capturedAt: item.capturedAt,
      latitude: item.latitude,
      longitude: item.longitude,
      notes: item.notes,
      status: cur.status,
      attempts: cur.attempts,
      nextAttemptAt: cur.nextAttemptAt,
      lastError: cur.lastError,
      lastErrorCode: cur.lastErrorCode,
      fieldErrors: cur.fieldErrors,
      createdAt: cur.createdAt,
      updatedAt: _ms,
      sentReportId: cur.sentReportId,
      sentAt: cur.sentAt,
      images: cur.images,
    );
    await _put(next);
    return next;
  }

  /// Registers [processed] (a normalised JPEG) as the next photo of [uuid].
  Future<OutboxImage> addImage(String uuid, File processed) async {
    final cur = _require(uuid);
    if (!_editable(cur.status)) {
      throw const OutboxFileException('Laporan tidak dapat diubah.');
    }
    if (cur.images.length >= OutboxFiles.maxImages) {
      await _tryDelete(processed);
      throw const OutboxFileException('Maksimal 5 foto per laporan.');
    }

    var file = processed;
    final dir = files.draftDir(uuid);
    if (!p.equals(p.dirname(file.path), dir.path)) {
      file = await processed.copy(p.join(dir.path, p.basename(processed.path)));
    }
    final position = cur.images.isEmpty
        ? 0
        : cur.images.map((i) => i.position).reduce(max) + 1;
    final image = OutboxImage(
      relPath: files.relPathFor(uuid, file),
      sizeBytes: await file.length(),
      position: position,
    );
    final images = [...cur.images, image];
    await store.replaceImages(uuid, images);
    await _put(cur.copyWith(images: images, updatedAt: _ms), persist: false);
    return image;
  }

  Future<void> removeImage(String uuid, OutboxImage image) async {
    final cur = _require(uuid);
    if (!_editable(cur.status)) return;
    final remaining = cur.images
        .where((i) => i.relPath != image.relPath)
        .toList();
    final renumbered = [
      for (var i = 0; i < remaining.length; i++)
        OutboxImage(
          id: remaining[i].id,
          relPath: remaining[i].relPath,
          sizeBytes: remaining[i].sizeBytes,
          position: i,
        ),
    ];
    await store.replaceImages(uuid, renumbered);
    await _put(
      cur.copyWith(images: renumbered, updatedAt: _ms),
      persist: false,
    );
    await files.deleteFile(image.relPath);
  }

  Future<void> discardDraft(String uuid) => remove(uuid);

  // ---- Sending ----

  /// Moves a draft or failed item to `pending` and uploads it right away.
  /// Returns the item in its final state (`sent`, `waiting`, `failed`, or
  /// `pending` when sending is blocked by a 401).
  Future<OutboxItem> submitNow(String uuid) async {
    final cur = _require(uuid);
    if (cur.status == OutboxStatus.draft || cur.status == OutboxStatus.failed) {
      await _put(
        cur.copyWith(
          status: OutboxStatus.pending,
          attempts: 0,
          nextAttemptAt: 0,
          clearError: true,
          updatedAt: _ms,
        ),
      );
    }
    await _synchronized(() => _process(uuid, onlyIfDue: false));
    final result = _find(uuid) ?? await store.get(uuid) ?? cur;
    unawaited(drain());
    return result;
  }

  /// Sends everything that is due, one item at a time. Concurrent calls share
  /// one run.
  Future<void> drain() {
    final running = _draining;
    if (running != null) return running;
    if (_userId == null || _blockedByAuth) return Future<void>.value();
    late final Future<void> future;
    future = _synchronized(_drainLoop).whenComplete(() {
      if (identical(_draining, future)) _draining = null;
      _armTimer();
    });
    _draining = future;
    return future;
  }

  Future<void> _drainLoop() async {
    final visited = <String>{};
    final gen = _generation;
    try {
      while (gen == _generation && !_blockedByAuth) {
        OutboxItem? next;
        for (final item in _items) {
          if (!visited.contains(item.uuid) && _isDue(item)) {
            next = item;
            break;
          }
        }
        if (next == null) break;
        visited.add(next.uuid);
        await _process(next.uuid, onlyIfDue: true);
      }
    } catch (e) {
      debugPrint('OutboxController: drain failed (${e.runtimeType})');
    }
  }

  bool _isDue(OutboxItem item) {
    if (item.userId != _userId) return false;
    if (item.status == OutboxStatus.pending) return true;
    return item.status == OutboxStatus.waiting && item.nextAttemptAt <= _ms;
  }

  Future<void> _process(String uuid, {required bool onlyIfDue}) async {
    final gen = _generation;
    var item = _find(uuid);
    if (item == null || item.userId != _userId) return;
    if (_blockedByAuth) return;
    final ready = onlyIfDue
        ? _isDue(item)
        : (item.status == OutboxStatus.pending ||
              item.status == OutboxStatus.waiting);
    if (!ready) return;

    final List<File> photos;
    try {
      photos = await files.validate(item);
    } on OutboxFileException {
      await _put(_failed(item, _kErrorFiles));
      return;
    }

    item = item.copyWith(status: OutboxStatus.uploading, updatedAt: _ms);
    await _put(item);
    _inFlightUuid = uuid;
    _setProgress(uuid, 0);

    try {
      final result = await _sender.create(
        item,
        photos,
        onProgress: (sent, total) {
          if (total > 0) _setProgress(uuid, sent / total);
        },
      );
      final sent = item.copyWith(
        status: OutboxStatus.sent,
        sentReportId: result.report.id,
        sentAt: _ms,
        images: const [],
        clearError: true,
        updatedAt: _ms,
      );
      // Photos are no longer needed once the server has the report.
      await store.replaceImages(uuid, const []);
      await files.deleteDir(uuid);
      await _put(sent, gen: gen);
    } on ApiException catch (e) {
      await _put(_afterError(item, e), gen: gen);
      if (e.failure == ApiFailure.unauthorized) _blockedByAuth = true;
    } catch (_) {
      // Unexpected local error: treat like a transient failure.
      await _put(
        _afterError(
          item,
          const ApiException(
            ApiFailure.unknown,
            'Terjadi kesalahan. Coba lagi.',
          ),
          transient: true,
        ),
        gen: gen,
      );
    } finally {
      _inFlightUuid = null;
      _clearProgress(uuid);
    }
  }

  OutboxItem _afterError(
    OutboxItem item,
    ApiException e, {
    bool transient = false,
  }) {
    if (e.failure == ApiFailure.unauthorized) {
      // Back to pending, attempts untouched. A later sign-in drains it.
      return item.copyWith(status: OutboxStatus.pending, updatedAt: _ms);
    }
    if (transient || e.isTransient) {
      final attempts = item.attempts + 1;
      final tooOld = _ms - item.createdAt > policy.maxAge.inMilliseconds;
      if (attempts >= policy.maxAttempts || tooOld) {
        return item.copyWith(
          status: OutboxStatus.failed,
          attempts: attempts,
          lastError: _kErrorRepeated,
          lastErrorCode: e.status,
          updatedAt: _ms,
        );
      }
      return item.copyWith(
        status: OutboxStatus.waiting,
        attempts: attempts,
        nextAttemptAt: _ms + _backoff(attempts, e.retryAfter).inMilliseconds,
        lastError: e.message,
        lastErrorCode: e.status,
        updatedAt: _ms,
      );
    }
    return item.copyWith(
      status: OutboxStatus.failed,
      lastError: e.message,
      lastErrorCode: e.status,
      fieldErrors: e.fieldErrors,
      updatedAt: _ms,
    );
  }

  Duration _backoff(int attempts, Duration? retryAfter) {
    final exp = policy.baseDelay.inMilliseconds * pow(2, max(0, attempts - 1));
    final capped = min(exp, policy.maxDelay.inMilliseconds.toDouble());
    final jittered = capped * (0.5 + _random.nextDouble() * 0.5);
    var delay = Duration(milliseconds: jittered.round());
    if (retryAfter != null && retryAfter > delay) delay = retryAfter;
    return delay;
  }

  OutboxItem _failed(OutboxItem item, String message) => item.copyWith(
    status: OutboxStatus.failed,
    lastError: message,
    updatedAt: _ms,
  );

  /// failed/waiting -> pending with the attempt counter reset, then drains.
  Future<void> retry(String uuid) async {
    final cur = _find(uuid);
    if (cur == null) return;
    if (cur.status != OutboxStatus.failed &&
        cur.status != OutboxStatus.waiting) {
      return;
    }
    await _put(
      cur.copyWith(
        status: OutboxStatus.pending,
        attempts: 0,
        nextAttemptAt: 0,
        clearError: true,
        updatedAt: _ms,
      ),
    );
    unawaited(drain());
  }

  /// Deletes the item, its rows and its photos. Ignored while uploading it.
  Future<void> remove(String uuid) async {
    if (_inFlightUuid == uuid) return;
    await store.delete(uuid);
    await files.deleteDir(uuid);
    _items = _items.where((i) => i.uuid != uuid).toList();
    _notify();
  }

  // ---- Timer ----

  void _armTimer() {
    _timer?.cancel();
    _timer = null;
    if (_paused || _disposed || _userId == null || _blockedByAuth) return;
    int? earliest;
    for (final item in _items) {
      if (item.status != OutboxStatus.waiting || item.userId != _userId) {
        continue;
      }
      if (earliest == null || item.nextAttemptAt < earliest) {
        earliest = item.nextAttemptAt;
      }
    }
    if (earliest == null) return;
    var delay = Duration(milliseconds: earliest - _ms);
    if (delay < const Duration(seconds: 1)) delay = const Duration(seconds: 1);
    if (delay > const Duration(minutes: 5)) delay = const Duration(minutes: 5);
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(drain());
    });
  }

  // ---- Helpers ----

  int get _ms => _now().millisecondsSinceEpoch;

  bool _editable(OutboxStatus s) =>
      s == OutboxStatus.draft || s == OutboxStatus.failed;

  int _requireUser() {
    final id = _userId;
    if (id == null) throw StateError('Antrean belum aktif.');
    return id;
  }

  OutboxItem? _find(String uuid) {
    for (final i in _items) {
      if (i.uuid == uuid) return i;
    }
    return null;
  }

  OutboxItem _require(String uuid) {
    final item = _find(uuid);
    if (item == null) throw StateError('Laporan tidak ditemukan di antrean.');
    return item;
  }

  /// Writes the item to the store and replaces it in memory. A change of
  /// user (sign-out during an upload) skips the in-memory part.
  Future<void> _put(OutboxItem item, {bool persist = true, int? gen}) async {
    if (persist) await store.update(item);
    if (gen != null && gen != _generation) return;
    _setInMemory(item);
  }

  void _setInMemory(OutboxItem item) {
    if (item.userId != _userId) return;
    final list = List<OutboxItem>.of(_items);
    final index = list.indexWhere((i) => i.uuid == item.uuid);
    if (index >= 0) {
      list[index] = item;
    } else {
      list.add(item);
    }
    _items = list;
    _notify();
  }

  void _setProgress(String uuid, double value) {
    if (_disposed) return;
    progress.value = {...progress.value, uuid: value.clamp(0.0, 1.0)};
  }

  void _clearProgress(String uuid) {
    if (_disposed) return;
    final next = {...progress.value}..remove(uuid);
    progress.value = next;
  }

  Future<void> _tryDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final previous = _tail;
    _tail = completer.future.then<void>((_) {}, onError: (_) {});
    previous.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    progress.dispose();
    super.dispose();
  }
}
