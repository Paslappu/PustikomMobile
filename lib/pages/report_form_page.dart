import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qrscan/models/device_model.dart';
import 'package:qrscan/models/gedung_model.dart';
import 'package:qrscan/models/outbox_item.dart';
import 'package:qrscan/pages/antrean_page.dart';
import 'package:qrscan/pages/base.dart';
import 'package:qrscan/services/app_scope.dart';
import 'package:qrscan/services/app_services.dart';
import 'package:qrscan/services/image_pipeline.dart';
import 'package:qrscan/services/location_service.dart';
import 'package:qrscan/services/outbox_files.dart';
import 'package:qrscan/theme/app_tokens.dart';
import 'package:qrscan/utils/formatters.dart';
import 'package:qrscan/widgets/app_button.dart';
import 'package:qrscan/widgets/app_card.dart';
import 'package:qrscan/widgets/app_snackbar.dart';
import 'package:qrscan/widgets/app_text_field.dart';
import 'package:qrscan/widgets/captured_time_picker.dart';
import 'package:qrscan/widgets/empty_state.dart';
import 'package:qrscan/widgets/gedung_picker_sheet.dart';
import 'package:qrscan/widgets/loading_overlay.dart';
import 'package:qrscan/widgets/photo_picker_grid.dart';
import 'package:qrscan/widgets/status_chip.dart';

/// Form for a new device report, or for resuming a draft / fixing a failed
/// queued report.
///
/// A new report passes [device]; resume and fix mode pass [uuid] of the outbox
/// row. The draft is persisted as soon as the form opens, so the uuid stays the
/// same for every retry.
class ReportFormPage extends StatefulWidget {
  const ReportFormPage({super.key, this.device, this.uuid});

  final DeviceModel? device;
  final String? uuid;

  @override
  State<ReportFormPage> createState() => _ReportFormPageState();
}

enum _LeaveChoice { save, discard, stay }

class _ReportFormPageState extends State<ReportFormPage>
    with WidgetsBindingObserver {
  static const int _notesMax = 2000;

  final _notesCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _bannerKey = GlobalKey();
  final _photoKey = GlobalKey();
  final _gedungKey = GlobalKey();
  final _notesKey = GlobalKey();
  final _gpsKey = GlobalKey();
  final _timeKey = GlobalKey();

  AppServices? _services;
  bool _started = false;

  String? _uuid;
  String? _loadError;
  bool _loading = true;
  bool _fixMode = false;

  // Editable fields (saved to the outbox on submit, pause and leave).
  int? _gedungId;
  String? _gedungLabel;
  DateTime _capturedAt = DateTime.now();
  double? _lat;
  double? _lng;
  double? _accuracy;

  // GPS state.
  bool _locating = false;
  LocationIssue? _gpsIssue;
  int _locationRequest = 0;

  // Photo state.
  bool _processing = false;
  String? _photoError;
  Set<int> _photoErrorIndexes = const {};

  // Submit state and server-side errors.
  bool _submitting = false;
  String? _banner;
  String? _notesError;
  String? _gedungError;
  String? _timeError;
  String? _gpsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services = AppScope.of(context);
    if (!_started) {
      _started = true;
      // After the first build, so setState is safe in every branch.
      Future<void>.microtask(_init);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationRequest++;
    _notesCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---- Helpers ----

  AppServices get _s => _services!;

  OutboxItem? get _current {
    final uuid = _uuid;
    if (uuid == null) return null;
    for (final item in _s.outbox.items) {
      if (item.uuid == uuid) return item;
    }
    return null;
  }

  List<OutboxImage> get _images {
    final list = [...?_current?.images]
      ..sort((a, b) => a.position.compareTo(b.position));
    return list;
  }

  bool get _hasContent =>
      _images.isNotEmpty || _notesCtrl.text.trim().isNotEmpty;

  bool get _canEditTime => _fixMode || _timeError != null;

  bool get _canSubmit =>
      _current != null &&
      _images.isNotEmpty &&
      !_processing &&
      !_submitting &&
      _notesCtrl.text.length <= _notesMax;

  String _labelFor(DeviceModel d) =>
      d.subtitle.isEmpty ? d.code : '${d.code} · ${d.subtitle}';

  // ---- Init ----

  Future<void> _init() async {
    if (!mounted) return;
    final outbox = _s.outbox;
    try {
      OutboxItem? item;
      final resumeUuid = widget.uuid;
      final device = widget.device;
      if (resumeUuid != null) {
        for (final i in outbox.items) {
          if (i.uuid == resumeUuid) item = i;
        }
        if (item == null) {
          _fail('Laporan tidak ditemukan di antrean.');
          return;
        }
        if (item.status != OutboxStatus.draft &&
            item.status != OutboxStatus.failed) {
          _fail(
            'Laporan ini sudah masuk antrean pengiriman dan tidak dapat diubah.',
          );
          return;
        }
      } else if (device != null) {
        item = await outbox.beginDraft(
          deviceId: device.id,
          deviceCode: device.code,
          deviceLabel: _labelFor(device),
        );
        if (!mounted) {
          unawaited(outbox.discardDraft(item.uuid));
          return;
        }
      } else {
        _fail('Perangkat tidak ditentukan.');
        return;
      }

      final ready = item;
      setState(() {
        _uuid = ready.uuid;
        _gedungId = ready.gedungId;
        _gedungLabel = ready.gedungLabel;
        _capturedAt =
            DateTime.tryParse(ready.capturedAt)?.toLocal() ?? DateTime.now();
        _lat = ready.latitude;
        _lng = ready.longitude;
        _notesCtrl.text = ready.notes;
        _fixMode = ready.status == OutboxStatus.failed;
        _loading = false;
        if (ready.status == OutboxStatus.failed) {
          if (ready.fieldErrors.isNotEmpty) {
            _applyFieldErrors(ready.fieldErrors);
          } else {
            _banner = ready.lastError;
          }
        }
      });
      if (!ready.hasCoordinates) unawaited(_captureLocation());
    } catch (_) {
      _fail('Draf laporan tidak dapat dibuat. Coba lagi.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loadError = message;
    });
  }

  // ---- Location ----

  Future<void> _captureLocation() async {
    if (_locating) return;
    final request = ++_locationRequest;
    setState(() {
      _locating = true;
      _gpsIssue = null;
      _gpsError = null;
    });
    final fix = await _s.location.capture();
    if (!mounted || request != _locationRequest) return;
    setState(() {
      _locating = false;
      if (fix.ok) {
        _lat = fix.latitude;
        _lng = fix.longitude;
        _accuracy = fix.accuracyMeters;
        _gpsIssue = null;
      } else {
        _gpsIssue = fix.issue ?? LocationIssue.error;
      }
    });
  }

  void _clearLocation() {
    _locationRequest++;
    setState(() {
      _locating = false;
      _lat = null;
      _lng = null;
      _accuracy = null;
      _gpsIssue = null;
      _gpsError = null;
    });
  }

  Future<void> _onGpsIssueAction() async {
    switch (_gpsIssue) {
      case LocationIssue.serviceDisabled:
        await _s.location.openLocationSettings();
      case LocationIssue.deniedForever:
        await _s.location.openAppSettings();
      default:
        await _captureLocation();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_current != null && !_submitting) unawaited(_saveFields());
    } else if (state == AppLifecycleState.resumed) {
      // Back from the system settings screen.
      if (_gpsIssue == LocationIssue.serviceDisabled ||
          _gpsIssue == LocationIssue.deniedForever) {
        unawaited(_captureLocation());
      }
    }
  }

  // ---- Fields ----

  Future<OutboxItem?> _saveFields() async {
    final cur = _current;
    if (cur == null) return null;
    try {
      final noCoords = _lat == null || _lng == null;
      return await _s.outbox.saveDraft(
        cur.copyWith(
          gedungId: _gedungId,
          gedungLabel: _gedungLabel,
          clearGedung: _gedungId == null,
          capturedAt: formatIsoWithOffset(_capturedAt),
          notes: _notesCtrl.text,
          latitude: _lat,
          longitude: _lng,
          clearCoordinates: noCoords,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickGedung() async {
    final pick = await showGedungPicker(context, selectedId: _gedungId);
    if (pick == null || !mounted) return;
    setState(() {
      _gedungId = pick.gedung?.id;
      _gedungLabel = pick.gedung?.label;
      _gedungError = null;
    });
  }

  void _useLastGedung(Gedung g) {
    setState(() {
      _gedungId = g.id;
      _gedungLabel = g.label;
      _gedungError = null;
    });
  }

  Future<void> _pickTime() async {
    final picked = await pickCapturedAt(context, _capturedAt);
    if (picked == null || !mounted) return;
    setState(() {
      _capturedAt = picked;
      _timeError = null;
    });
  }

  void _useNow() {
    setState(() {
      _capturedAt = DateTime.now();
      _timeError = null;
    });
  }

  // ---- Photos ----

  Future<List<File>> _pick(ImageSourceKind kind, int remaining) async {
    final source = _s.images.source;
    if (kind == ImageSourceKind.camera) {
      final file = await source.pickCamera();
      return file == null ? const [] : [file];
    }
    return source.pickGallery(limit: remaining);
  }

  Future<void> _addPhotos(ImageSourceKind kind) async {
    final uuid = _uuid;
    if (uuid == null || _processing) return;
    final outbox = _s.outbox;
    final remaining = OutboxFiles.maxImages - _images.length;
    if (remaining <= 0) return;

    setState(() {
      _processing = true;
      _photoError = null;
      _photoErrorIndexes = const {};
    });

    final errors = <String>[];
    try {
      final picked = await _pick(kind, remaining);
      var number = 0;
      for (final file in picked.take(remaining)) {
        number++;
        if (!mounted) return;
        try {
          final processed = await _s.images.normalize(
            file,
            outbox.files.draftDir(uuid),
            position: _images.length,
          );
          if (!mounted) return;
          await outbox.addImage(uuid, processed);
        } on ImageFormatException catch (e) {
          errors.add(
            picked.length > 1 ? 'Foto $number: ${e.message}' : e.message,
          );
        } on ImageTooLargeException catch (e) {
          errors.add(
            picked.length > 1 ? 'Foto $number: ${e.message}' : e.message,
          );
        } on OutboxFileException catch (e) {
          errors.add(e.message);
        }
      }
    } on PlatformException catch (e) {
      errors.add(
        e.code.contains('denied')
            ? 'Izin kamera atau galeri ditolak. Aktifkan izin di pengaturan perangkat.'
            : 'Foto tidak dapat diambil.',
      );
    } catch (_) {
      errors.add('Foto tidak dapat diambil.');
    }

    if (!mounted) return;
    setState(() {
      _processing = false;
      _photoError = errors.isEmpty ? null : errors.join('\n');
    });
  }

  Future<void> _removePhoto(OutboxImage image) async {
    final uuid = _uuid;
    if (uuid == null) return;
    await _s.outbox.removeImage(uuid, image);
    if (!mounted) return;
    setState(() {
      _photoError = null;
      _photoErrorIndexes = const {};
    });
  }

  // ---- Submit ----

  Future<void> _submit() async {
    final uuid = _uuid;
    if (uuid == null || !_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _banner = null;
      _notesError = null;
      _gedungError = null;
      _timeError = null;
      _gpsError = null;
      _photoError = null;
      _photoErrorIndexes = const {};
    });
    try {
      await _saveFields();
      final result = await _s.outbox.submitNow(uuid);
      if (!mounted) return;
      setState(() => _submitting = false);
      await _handleOutcome(result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(
        context,
        'Laporan tidak dapat dikirim. Coba lagi.',
        isError: true,
      );
    }
  }

  Future<void> _handleOutcome(OutboxItem result) async {
    final services = _s;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    switch (result.status) {
      case OutboxStatus.sent:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Laporan terkirim.')));
        nav.popUntil((r) => r.isFirst);
        services.shellTab.value = BaseHome.reportsTab;
      case OutboxStatus.waiting:
      case OutboxStatus.pending:
        // After a 401 the global handler signs out and `main.dart` pops us.
        if (services.outbox.blockedByAuth) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text(
                'Tidak ada koneksi. Laporan disimpan di antrean dan akan '
                'dikirim otomatis.',
              ),
              action: SnackBarAction(
                label: 'Lihat',
                onPressed: () => nav.push<void>(
                  MaterialPageRoute(builder: (_) => const AntreanPage()),
                ),
              ),
            ),
          );
        nav.popUntil((r) => r.isFirst);
      case OutboxStatus.failed:
        await _handleFailed(result);
      case OutboxStatus.draft:
      case OutboxStatus.uploading:
        break;
    }
  }

  Future<void> _handleFailed(OutboxItem result) async {
    final code = result.lastErrorCode;
    if (code == 409) {
      await _showConflictDialog();
      return;
    }
    setState(() {
      _fixMode = true;
      if (code == 413) {
        _photoError =
            'Ukuran unggahan melebihi batas server. Kurangi jumlah foto.';
      } else if (result.fieldErrors.isNotEmpty) {
        _applyFieldErrors(result.fieldErrors);
      } else {
        _banner = result.lastError ?? 'Laporan gagal dikirim.';
      }
    });
    _scrollToFirstError();
  }

  Future<void> _showConflictDialog() async {
    final uuid = _uuid;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Laporan tidak dapat dikirim'),
        content: const Text('ID laporan sudah dipakai pengguna lain.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hapus draf'),
          ),
        ],
      ),
    );
    if (uuid != null) await _s.outbox.discardDraft(uuid);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// Maps 422 field keys to the matching part of the form.
  void _applyFieldErrors(Map<String, List<String>> errors) {
    String? first(String key) {
      final list = errors[key];
      return (list == null || list.isEmpty) ? null : list.first;
    }

    final lines = <String>[];
    final indexes = <int>{};
    String? other;
    errors.forEach((key, list) {
      if (list.isEmpty) return;
      if (key == 'images') {
        lines.add(list.first);
      } else if (key.startsWith('images.')) {
        final n = int.tryParse(key.substring('images.'.length));
        if (n != null) {
          indexes.add(n);
          lines.add('Foto ${n + 1}: ${list.first}');
        } else {
          lines.add(list.first);
        }
      } else if (!const {
        'notes',
        'gedung_id',
        'captured_at',
        'latitude',
        'longitude',
        'device_id',
        'uuid',
      }.contains(key)) {
        other ??= list.first;
      }
    });

    _photoError = lines.isEmpty ? null : lines.join('\n');
    _photoErrorIndexes = indexes;
    _notesError = first('notes');
    _gedungError = first('gedung_id');
    _timeError = first('captured_at');
    _gpsError = first('latitude') ?? first('longitude');
    _banner = first('device_id') ?? first('uuid') ?? other;
  }

  void _scrollToFirstError() {
    final keys = <GlobalKey>[
      if (_banner != null) _bannerKey,
      if (_photoError != null) _photoKey,
      if (_gedungError != null) _gedungKey,
      if (_notesError != null) _notesKey,
      if (_gpsError != null) _gpsKey,
      if (_timeError != null) _timeKey,
    ];
    if (keys.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = keys.first.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.1,
        duration: const Duration(milliseconds: 250),
      );
    });
  }

  // ---- Leaving ----

  bool get _canPopFreely => _current == null || _loadError != null;

  Future<void> _onBack() async {
    if (_submitting || _processing) return;
    final cur = _current;
    final uuid = _uuid;
    if (cur == null || uuid == null) return;
    final outbox = _s.outbox;
    final isDraft = cur.status == OutboxStatus.draft;

    if (isDraft && !_hasContent) {
      await outbox.discardDraft(uuid);
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    final choice = await showDialog<_LeaveChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isDraft ? 'Simpan draf?' : 'Simpan perubahan?'),
        content: Text(
          isDraft
              ? 'Laporan belum dikirim. Simpan sebagai draf atau buang?'
              : 'Laporan ini belum terkirim. Simpan perubahan atau hapus dari antrean?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.stay),
            child: const Text('Lanjutkan'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.discard),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(isDraft ? 'Buang' : 'Hapus laporan'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.save),
            child: Text(isDraft ? 'Simpan draf' : 'Simpan'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case _LeaveChoice.save:
        await _saveFields();
        if (!mounted) return;
        Navigator.of(context).pop();
      case _LeaveChoice.discard:
        await outbox.discardDraft(uuid);
        if (!mounted) return;
        Navigator.of(context).pop();
      case _LeaveChoice.stay:
      case null:
        break;
    }
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final outbox = _s.outbox;
    return PopScope(
      canPop: _canPopFreely,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBack());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_fixMode ? 'Perbaiki Laporan' : 'Buat Laporan'),
        ),
        body: ValueListenableBuilder<Map<String, double>>(
          valueListenable: outbox.progress,
          builder: (context, progress, _) => LoadingOverlay(
            isLoading: _submitting,
            message: 'Mengirim laporan...',
            progress: _uuid == null ? null : progress[_uuid],
            child: _buildBody(),
          ),
        ),
        bottomNavigationBar: (_current == null || _loadError != null)
            ? null
            : _SubmitBar(
                enabled: _canSubmit,
                hint: _images.isEmpty ? 'Tambahkan minimal 1 foto.' : null,
                onSubmit: _submit,
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Formulir tidak dapat dibuka',
        message: _loadError,
        actionLabel: 'Kembali',
        onAction: () => Navigator.of(context).maybePop(),
      );
    }

    final device = widget.device;
    final cur = _current;
    final lastGedung = device?.currentLocation?.gedung;
    final disabled = _submitting;

    return ListView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      children: [
        if (_banner != null) ...[
          _ErrorBanner(key: _bannerKey, message: _banner!),
          const SizedBox(height: 12),
        ],
        _DeviceSummaryCard(device: device, label: cur?.deviceLabel ?? ''),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _photoKey,
          child: PhotoPickerGrid(
            images: _images,
            resolve: (image) => _s.outbox.files.resolve(image.relPath),
            busy: _processing,
            enabled: !disabled,
            onAdd: _addPhotos,
            onRemove: _removePhoto,
            errorText: _photoError,
            errorIndexes: _photoErrorIndexes,
          ),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _gedungKey,
          child: _GedungField(
            label: _gedungLabel,
            errorText: _gedungError,
            suggestion: (lastGedung != null && lastGedung.id != _gedungId)
                ? lastGedung
                : null,
            onTap: disabled ? null : _pickGedung,
            onUseSuggestion: disabled ? null : _useLastGedung,
            onClear: (_gedungId == null || disabled)
                ? null
                : () => setState(() {
                    _gedungId = null;
                    _gedungLabel = null;
                  }),
          ),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _notesKey,
          child: _NotesField(
            controller: _notesCtrl,
            max: _notesMax,
            errorText: _notesError,
            onChanged: (_) => setState(() => _notesError = null),
          ),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _gpsKey,
          child: _GpsCard(
            locating: _locating,
            hasFix: _lat != null && _lng != null,
            accuracyMeters: _accuracy,
            issue: _gpsIssue,
            errorText: _gpsError,
            onIssueAction: _onGpsIssueAction,
            onRefresh: _captureLocation,
            onClear: _clearLocation,
          ),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _timeKey,
          child: AppCard(
            child: CapturedTimeRow(
              capturedAt: _capturedAt,
              errorText: _timeError,
              onPick: (_canEditTime && !disabled) ? _pickTime : null,
              onUseNow: (_canEditTime && !disabled) ? _useNow : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.enabled, required this.onSubmit, this.hint});

  final bool enabled;
  final String? hint;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hint != null) ...[
              Text(hint!, style: context.text.bodySmall),
              const SizedBox(height: 8),
            ],
            AppButton(
              label: 'Kirim Laporan',
              icon: Icons.send_outlined,
              onPressed: enabled ? onSubmit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppCard(
      color: tokens.dangerContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: tokens.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: context.text.bodyMedium?.copyWith(color: tokens.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceSummaryCard extends StatelessWidget {
  const _DeviceSummaryCard({required this.device, required this.label});

  final DeviceModel? device;

  /// Stored label, used when resuming a draft without a [DeviceModel].
  final String label;

  @override
  Widget build(BuildContext context) {
    final d = device;
    final text = context.text;
    return AppCard(
      child: Row(
        children: [
          Icon(Icons.devices_other_outlined, color: context.colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d?.code ?? label,
                  style: text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (d != null && d.subtitle.isNotEmpty)
                  Text(d.subtitle, style: text.bodySmall),
              ],
            ),
          ),
          if (d != null) ...[
            const SizedBox(width: 8),
            StatusChip(
              label: d.isActive ? 'Aktif' : 'Nonaktif',
              tone: d.isActive ? StatusTone.success : StatusTone.neutral,
            ),
          ],
        ],
      ),
    );
  }
}

class _GedungField extends StatelessWidget {
  const _GedungField({
    required this.label,
    required this.errorText,
    required this.suggestion,
    required this.onTap,
    required this.onUseSuggestion,
    required this.onClear,
  });

  final String? label;
  final String? errorText;
  final Gedung? suggestion;
  final VoidCallback? onTap;
  final ValueChanged<Gedung>? onUseSuggestion;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final scheme = context.colors;
    final selected = label != null && label!.isNotEmpty;
    final s = suggestion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gedung / lokasi', style: text.labelMedium),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(context.tokens.radiusMd),
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.apartment_outlined),
              suffixIcon: selected && onClear != null
                  ? IconButton(
                      tooltip: 'Hapus pilihan gedung',
                      icon: const Icon(Icons.close),
                      onPressed: onClear,
                    )
                  : const Icon(Icons.arrow_drop_down),
              errorText: errorText,
            ),
            child: Text(
              selected ? label! : 'Pilih gedung (opsional)',
              style: text.bodyMedium?.copyWith(
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (s != null && onUseSuggestion != null) ...[
          const SizedBox(height: 8),
          ActionChip(
            avatar: const Icon(Icons.history, size: 18),
            label: Text(
              'Gunakan lokasi terakhir: ${s.label}',
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () => onUseSuggestion!(s),
          ),
        ],
      ],
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({
    required this.controller,
    required this.max,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int max;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: controller,
          label: 'Catatan',
          hint: 'Kondisi perangkat, kendala, dan keterangan lain',
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          inputFormatters: [LengthLimitingTextInputFormatter(max)],
          errorText: errorText,
          onChanged: onChanged,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => Text(
              '${value.text.length}/$max',
              style: context.text.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}

class _GpsCard extends StatelessWidget {
  const _GpsCard({
    required this.locating,
    required this.hasFix,
    required this.accuracyMeters,
    required this.issue,
    required this.errorText,
    required this.onIssueAction,
    required this.onRefresh,
    required this.onClear,
  });

  final bool locating;
  final bool hasFix;
  final double? accuracyMeters;
  final LocationIssue? issue;
  final String? errorText;
  final VoidCallback onIssueAction;
  final VoidCallback onRefresh;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final scheme = context.colors;
    final tokens = context.tokens;

    final String title;
    final IconData icon;
    Color color = scheme.onSurfaceVariant;
    String? actionLabel;
    if (locating) {
      title = 'Mencari lokasi...';
      icon = Icons.my_location;
    } else if (issue != null) {
      icon = Icons.location_off_outlined;
      color = tokens.warning;
      (title, actionLabel) = switch (issue!) {
        LocationIssue.serviceDisabled => (
          'GPS nonaktif',
          'Buka pengaturan lokasi',
        ),
        LocationIssue.denied => ('Izin lokasi ditolak', 'Coba lagi'),
        LocationIssue.deniedForever => (
          'Izin lokasi ditolak permanen',
          'Buka pengaturan',
        ),
        LocationIssue.timeout ||
        LocationIssue.error => ('Lokasi tidak tersedia', 'Coba lagi'),
      };
    } else if (hasFix) {
      icon = Icons.location_on;
      color = tokens.success;
      final m = accuracyMeters;
      title = m == null ? 'Lokasi didapat' : 'Lokasi didapat (±${m.round()} m)';
    } else {
      icon = Icons.location_off_outlined;
      title = 'Lokasi tidak disertakan';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (locating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: text.titleSmall)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Lokasi GPS bersifat opsional. Laporan tetap dapat dikirim tanpa lokasi.',
            style: text.bodySmall,
          ),
          if (errorText != null) ...[
            const SizedBox(height: 4),
            Text(
              errorText!,
              style: text.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              if (actionLabel != null)
                TextButton(onPressed: onIssueAction, child: Text(actionLabel)),
              if (!locating)
                TextButton(
                  onPressed: onRefresh,
                  child: Text(hasFix ? 'Perbarui lokasi' : 'Ambil lokasi'),
                ),
              if (!locating && hasFix)
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  child: const Text('Hapus lokasi'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
