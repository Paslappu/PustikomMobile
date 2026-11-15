import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:qrscan/services/api_client.dart';
import 'package:qrscan/services/auth_controller.dart';
import 'package:qrscan/services/database_service.dart';
import 'package:qrscan/services/device_service.dart';
import 'package:qrscan/services/image_pipeline.dart';
import 'package:qrscan/services/location_service.dart';
import 'package:qrscan/services/outbox_controller.dart';
import 'package:qrscan/services/outbox_files.dart';
import 'package:qrscan/services/reference_repository.dart';
import 'package:qrscan/services/report_service.dart';

/// Everything the screens need, created once in `MyApp` and exposed through
/// `AppScope`. Tests build it with fakes.
class AppServices {
  AppServices({
    required this.api,
    required this.auth,
    required this.references,
    required this.devices,
    required this.reports,
    required this.outbox,
    required this.location,
    required this.images,
    ValueNotifier<int>? shellTab,
  }) : shellTab = shellTab ?? ValueNotifier<int>(0) {
    auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  /// Wires the real implementations. [documentsDir] hosts the outbox photos.
  factory AppServices.create({
    required ApiClient api,
    required AuthController auth,
    required Directory documentsDir,
  }) {
    final reports = HttpReportService(api);
    return AppServices(
      api: api,
      auth: auth,
      references: ReferenceRepository(api: api),
      devices: HttpDeviceService(api),
      reports: reports,
      outbox: OutboxController(
        store: DatabaseService.instance,
        sender: reports,
        files: OutboxFiles(Directory(p.join(documentsDir.path, 'outbox'))),
      ),
      location: LocationService(),
      images: ImagePipeline(),
    );
  }

  final ApiClient api;
  final AuthController auth;
  final ReferenceRepository references;
  final DeviceService devices;
  final ReportService reports;
  final OutboxController outbox;
  final LocationService location;
  final ImagePipeline images;

  /// Selected tab of the signed-in shell, so any screen can switch tabs.
  final ValueNotifier<int> shellTab;

  AuthStatus? _lastStatus;
  int? _lastUserId;
  bool _disposed = false;

  void _onAuthChanged() {
    final status = auth.status;
    final userId = auth.user?.id;
    if (status == _lastStatus && userId == _lastUserId) return;
    _lastStatus = status;
    _lastUserId = userId;

    if (status == AuthStatus.signedIn && userId != null) {
      unawaited(_onSignedIn(userId));
    } else if (status == AuthStatus.signedOut) {
      outbox.detach();
      shellTab.value = 0;
    }
  }

  Future<void> _onSignedIn(int userId) async {
    unawaited(references.load(force: true).catchError((_) {}));
    try {
      await outbox.attach(userId);
      if (_disposed) return;
      await _recoverLostPhotos();
    } catch (e) {
      debugPrint('AppServices: sign-in setup failed (${e.runtimeType})');
    }
  }

  /// Android may kill the activity while the camera is open. The picked photo
  /// is then attached to the newest draft of the current user.
  Future<void> _recoverLostPhotos() async {
    final lost = await images.recoverLost();
    if (lost.isEmpty) return;
    final drafts = outbox.drafts;
    if (drafts.isEmpty) return;
    final draft = drafts.reduce((a, b) => a.createdAt >= b.createdAt ? a : b);
    var count = draft.images.length;
    for (final file in lost) {
      if (count >= OutboxFiles.maxImages) break;
      try {
        final processed = await images.normalize(
          file,
          outbox.files.draftDir(draft.uuid),
          position: count,
        );
        await outbox.addImage(draft.uuid, processed);
        count++;
      } catch (_) {
        // Skip photos that cannot be processed.
      }
    }
  }

  /// Forwarded from `MyApp`'s lifecycle observer.
  void onAppResumed() => outbox.onResumed();

  void onAppPaused() => outbox.onPaused();

  void dispose() {
    _disposed = true;
    auth.removeListener(_onAuthChanged);
    outbox.dispose();
    references.dispose();
    reports.revision.dispose();
    shellTab.dispose();
  }
}
