import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qrscan/models/report_model.dart';
import 'package:qrscan/pages/device_detail_page.dart';
import 'package:qrscan/pages/report_edit_page.dart';
import 'package:qrscan/services/api_exception.dart';
import 'package:qrscan/services/app_scope.dart';
import 'package:qrscan/services/app_services.dart';
import 'package:qrscan/services/auth_scope.dart';
import 'package:qrscan/services/image_pipeline.dart';
import 'package:qrscan/services/outbox_files.dart';
import 'package:qrscan/theme/app_tokens.dart';
import 'package:qrscan/utils/formatters.dart';
import 'package:qrscan/widgets/app_button.dart';
import 'package:qrscan/widgets/app_card.dart';
import 'package:qrscan/widgets/app_snackbar.dart';
import 'package:qrscan/widgets/confirm_dialog.dart';
import 'package:qrscan/widgets/empty_state.dart';
import 'package:qrscan/widgets/info_tile.dart';
import 'package:qrscan/widgets/loading_overlay.dart';
import 'package:qrscan/widgets/network_thumb.dart';
import 'package:qrscan/widgets/photo_picker_grid.dart';
import 'package:qrscan/widgets/photo_viewer.dart';
import 'package:qrscan/widgets/section_header.dart';
import 'package:url_launcher/url_launcher.dart';

/// A report loaded from the server: photos, device, building, notes, times
/// and author, with edit, delete and photo management for its owner or an
/// admin.
class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({super.key, required this.id});

  /// Server id of the report (`GET /device-reports/{id}`).
  final int id;

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

enum _MenuAction { edit, delete }

class _ReportDetailPageState extends State<ReportDetailPage> {
  static const int _maxPhotos = OutboxFiles.maxImages;

  AppServices? _services;
  DeviceReport? _report;
  bool _loading = true;
  ApiFailure? _failure;
  String? _error;
  int _requestId = 0;

  bool _busy = false;
  String? _busyMessage;
  double? _busyProgress;

  AppServices get _s => _services!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      _services = AppScope.of(context);
      unawaited(_load());
    }
  }

  // ---- Loading ----

  Future<void> _load({bool silent = false}) async {
    final id = ++_requestId;
    if (!silent) {
      setState(() {
        _loading = true;
        _failure = null;
        _error = null;
      });
    }
    try {
      final report = await _s.reports.get(widget.id);
      if (!mounted || id != _requestId) return;
      setState(() {
        _report = report;
        _loading = false;
        _failure = null;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      if (e.failure == ApiFailure.notFound) {
        // Tell the lists that this report is gone.
        _s.reports.revision.value++;
      }
      if (silent && _report != null && e.failure != ApiFailure.notFound) {
        if (e.failure != ApiFailure.unauthorized) {
          showAppSnackBar(context, e.message, isError: true);
        }
        return;
      }
      setState(() {
        _loading = false;
        _failure = e.failure;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _failure = ApiFailure.unknown;
        _error = 'Terjadi kesalahan. Coba lagi.';
      });
    }
  }

  bool _canManage(DeviceReport report) {
    final user = AuthScope.of(context).user;
    if (user == null) return false;
    return user.isAdmin || report.user?.id == user.id;
  }

  void _showApiError(ApiException e) {
    if (!mounted || e.failure == ApiFailure.unauthorized) return;
    showAppSnackBar(context, e.message, isError: true);
  }

  // ---- Actions ----

  Future<void> _edit(DeviceReport report) async {
    final updated = await Navigator.of(context).push<DeviceReport>(
      MaterialPageRoute(builder: (_) => ReportEditPage(report: report)),
    );
    if (updated == null || !mounted) return;
    showAppSnackBar(context, 'Perubahan disimpan.');
    await _load(silent: true);
  }

  Future<void> _delete(DeviceReport report) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus laporan?',
      message:
          'Laporan beserta semua fotonya akan dihapus dan tidak dapat '
          'dikembalikan.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _busyMessage = 'Menghapus laporan...';
      _busyProgress = null;
    });
    try {
      await _s.reports.delete(report.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Laporan dihapus.')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showApiError(e);
    }
  }

  Future<void> _openDevice(DeviceReport report) async {
    setState(() {
      _busy = true;
      _busyMessage = 'Memuat perangkat...';
      _busyProgress = null;
    });
    try {
      final device = await _s.devices.getById(report.deviceId);
      if (!mounted) return;
      setState(() => _busy = false);
      await DeviceDetailPage.openFromScan(context, device);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showApiError(e);
    }
  }

  Future<void> _openMap(DeviceReport report) async {
    final lat = report.latitude;
    final lng = report.longitude;
    if (lat == null || lng == null) return;
    final coords = '$lat,$lng';
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse('https://www.google.com/maps?q=$coords'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened || !mounted) return;
    await Clipboard.setData(ClipboardData(text: coords));
    if (!mounted) return;
    showAppSnackBar(
      context,
      'Tidak dapat membuka peta. Koordinat disalin ke papan klip.',
    );
  }

  Future<void> _openViewer(DeviceReport report, int index) {
    final canManage = _canManage(report);
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PhotoViewerPage(
          urls: [for (final i in report.images) i.url],
          initialIndex: index,
          onDelete: canManage ? _deleteImage : null,
        ),
      ),
    );
  }

  Future<bool> _deleteImage(int index, String url) async {
    final report = _report;
    if (report == null) return false;
    ReportImage? image;
    for (final i in report.images) {
      if (i.url == url) image = i;
    }
    if (image == null) return false;
    try {
      await _s.reports.deleteImage(report.id, image.id);
    } on ApiException catch (e) {
      if (!mounted || e.failure == ApiFailure.unauthorized) return false;
      final lastPhoto =
          e.failure == ApiFailure.validation &&
          e.fieldErrors.containsKey('image');
      showAppSnackBar(
        context,
        lastPhoto ? 'Laporan minimal harus memiliki 1 foto.' : e.message,
        isError: true,
      );
      return false;
    }
    if (mounted) unawaited(_load(silent: true));
    return true;
  }

  Future<void> _addPhotos(DeviceReport report) async {
    final remaining = _maxPhotos - report.images.length;
    if (remaining <= 0) return;
    final kind = await showImageSourceSheet(context);
    if (kind == null || !mounted) return;

    setState(() {
      _busy = true;
      _busyMessage = 'Memproses foto...';
      _busyProgress = null;
    });

    Directory? workDir;
    var message = '';
    var isError = false;
    try {
      final source = _s.images.source;
      final List<File> picked;
      if (kind == ImageSourceKind.camera) {
        final file = await source.pickCamera();
        picked = file == null ? const [] : [file];
      } else {
        picked = await source.pickGallery(limit: remaining);
      }

      final processed = <File>[];
      if (picked.isNotEmpty) {
        final temp = await getTemporaryDirectory();
        workDir = Directory(p.join(temp.path, 'report_upload_${report.id}'));
        final errors = <String>[];
        var number = 0;
        for (final file in picked.take(remaining)) {
          number++;
          try {
            processed.add(
              await _s.images.normalize(file, workDir, position: number),
            );
          } on ImageFormatException catch (e) {
            errors.add('Foto $number: ${e.message}');
          } on ImageTooLargeException catch (e) {
            errors.add('Foto $number: ${e.message}');
          }
        }
        if (errors.isNotEmpty) {
          message = errors.join('\n');
          isError = true;
        }
      }

      if (processed.isNotEmpty) {
        if (!mounted) return;
        setState(() => _busyMessage = 'Mengunggah foto...');
        await _s.reports.addImages(
          report.id,
          processed,
          onProgress: (sent, total) {
            if (mounted && total > 0) {
              setState(() => _busyProgress = sent / total);
            }
          },
        );
        message = 'Foto ditambahkan.';
        isError = false;
      }
    } on ApiException catch (e) {
      if (e.failure == ApiFailure.unauthorized) {
        message = '';
      } else {
        message = e.firstError('images') ?? e.message;
        isError = true;
      }
    } on PlatformException catch (e) {
      message = e.code.contains('denied')
          ? 'Izin kamera atau galeri ditolak. Aktifkan izin di pengaturan perangkat.'
          : 'Foto tidak dapat diambil.';
      isError = true;
    } catch (_) {
      message = 'Foto tidak dapat diproses.';
      isError = true;
    } finally {
      if (workDir != null) {
        try {
          if (await workDir.exists()) await workDir.delete(recursive: true);
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _busyProgress = null;
    });
    if (message.isNotEmpty) showAppSnackBar(context, message, isError: isError);
    unawaited(_load(silent: true));
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Laporan'),
        actions: [
          if (report != null && _canManage(report))
            PopupMenuButton<_MenuAction>(
              enabled: !_busy,
              onSelected: (action) {
                switch (action) {
                  case _MenuAction.edit:
                    unawaited(_edit(report));
                  case _MenuAction.delete:
                    unawaited(_delete(report));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: _MenuAction.edit, child: Text('Ubah')),
                PopupMenuItem(value: _MenuAction.delete, child: Text('Hapus')),
              ],
            ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _busy,
        message: _busyMessage,
        progress: _busyProgress,
        child: _buildBody(report),
      ),
    );
  }

  Widget _buildBody(DeviceReport? report) {
    if (_loading && report == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (report == null) {
      return switch (_failure) {
        ApiFailure.forbidden => EmptyState(
          icon: Icons.lock_outline,
          title: 'Anda tidak memiliki akses ke laporan ini.',
          actionLabel: 'Kembali',
          onAction: () => Navigator.of(context).maybePop(),
        ),
        ApiFailure.notFound => EmptyState(
          icon: Icons.search_off,
          title: 'Laporan tidak ditemukan.',
          message: 'Laporan ini mungkin sudah dihapus.',
          actionLabel: 'Kembali',
          onAction: () => Navigator.of(context).maybePop(),
        ),
        _ => EmptyState(
          icon: Icons.error_outline,
          title: 'Gagal memuat laporan',
          message: _error,
          actionLabel: 'Coba Lagi',
          onAction: _load,
        ),
      };
    }

    final canManage = _canManage(report);
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(title: 'Foto (${report.images.length}/$_maxPhotos)'),
          const SizedBox(height: 8),
          _PhotoStrip(
            images: report.images,
            onTap: (i) => _openViewer(report, i),
          ),
          if (canManage && report.images.length < _maxPhotos) ...[
            const SizedBox(height: 8),
            AppButton(
              label: 'Tambah Foto',
              icon: Icons.add_a_photo_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: _busy ? null : () => _addPhotos(report),
            ),
          ],
          const SizedBox(height: 16),
          _DetailCard(
            report: report,
            onOpenDevice: () => _openDevice(report),
            onOpenMap: () => _openMap(report),
          ),
        ],
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.images, required this.onTap});

  final List<ReportImage> images;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return AppCard(
        child: Text(
          'Laporan ini tidak memiliki foto.',
          style: context.text.bodyMedium,
        ),
      );
    }
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) =>
            NetworkThumb(url: images[i].url, size: 112, onTap: () => onTap(i)),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.report,
    required this.onOpenDevice,
    required this.onOpenMap,
  });

  final DeviceReport report;
  final VoidCallback onOpenDevice;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final notes = report.notes?.trim() ?? '';
    final gedung = report.gedung?.label ?? '';
    final user = report.user?.name ?? '';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpenDevice,
            child: Row(
              children: [
                Expanded(
                  child: InfoTile(
                    label: 'Perangkat',
                    value: report.device?.code ?? '#${report.deviceId}',
                    icon: Icons.devices_other_outlined,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: context.colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
          InfoTile(
            label: 'Gedung',
            value: gedung,
            icon: Icons.apartment_outlined,
          ),
          InfoTile(
            label: 'Catatan',
            value: notes,
            icon: Icons.notes_outlined,
            selectable: true,
          ),
          InfoTile(
            label: 'Waktu pengambilan',
            value: formatDateTime(report.capturedAt.toLocal()),
            icon: Icons.schedule,
          ),
          InfoTile(label: 'Pelapor', value: user, icon: Icons.person_outline),
          InfoTile(
            label: 'Dibuat',
            value: formatDateTime(report.createdAt.toLocal()),
            icon: Icons.event_outlined,
          ),
          InfoTile(
            label: 'Diperbarui',
            value: formatDateTime(report.updatedAt.toLocal()),
            icon: Icons.update,
          ),
          if (report.hasCoordinates)
            InkWell(
              onTap: onOpenMap,
              child: Row(
                children: [
                  Expanded(
                    child: InfoTile(
                      label: 'Lokasi GPS',
                      value: 'Buka di Peta',
                      icon: Icons.map_outlined,
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: context.colors.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
