import 'package:flutter/material.dart';
import 'package:qrscan/models/device_model.dart';
import 'package:qrscan/pages/device_reports_page.dart';
import 'package:qrscan/pages/report_form_page.dart';
import 'package:qrscan/services/api_exception.dart';
import 'package:qrscan/services/app_scope.dart';
import 'package:qrscan/theme/app_tokens.dart';
import 'package:qrscan/utils/formatters.dart';
import 'package:qrscan/widgets/app_button.dart';
import 'package:qrscan/widgets/app_card.dart';
import 'package:qrscan/widgets/app_snackbar.dart';
import 'package:qrscan/widgets/empty_state.dart';
import 'package:qrscan/widgets/info_tile.dart';
import 'package:qrscan/widgets/location_map.dart';
import 'package:qrscan/widgets/network_thumb.dart';
import 'package:qrscan/widgets/photo_viewer.dart';
import 'package:qrscan/widgets/section_header.dart';
import 'package:qrscan/widgets/status_chip.dart';

class DeviceDetailPage extends StatefulWidget {
  const DeviceDetailPage({super.key, required this.device});

  final DeviceModel device;

  /// Opens the detail screen for a device found by scanning or typing a code.
  /// Completes when the user comes back.
  static Future<void> openFromScan(BuildContext context, DeviceModel device) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => DeviceDetailPage(device: device)),
    );
  }

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  late DeviceModel _device = widget.device;
  bool _notFound = false;

  Future<void> _refresh() async {
    final devices = AppScope.of(context).devices;
    try {
      final fresh = await devices.getById(_device.id);
      if (!mounted) return;
      setState(() {
        _device = fresh;
        _notFound = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.failure == ApiFailure.notFound) {
        setState(() => _notFound = true);
      } else if (e.failure != ApiFailure.unauthorized) {
        showAppSnackBar(context, e.message, isError: true);
      }
    }
  }

  void _createReport() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ReportFormPage(device: _device)),
    );
  }

  void _openHistory() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            DeviceReportsPage(deviceId: _device.id, deviceCode: _device.code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Perangkat')),
      body: _notFound
          ? EmptyState(
              icon: Icons.search_off,
              title: 'Perangkat tidak ditemukan',
              message: 'Perangkat ini mungkin sudah dihapus.',
              actionLabel: 'Kembali',
              onAction: () => Navigator.of(context).maybePop(),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(device: _device),
                  if (!_device.isActive) ...[
                    const SizedBox(height: 12),
                    const _InactiveBanner(),
                  ],
                  const SizedBox(height: 16),
                  const SectionHeader(title: 'Lokasi Saat Ini'),
                  const SizedBox(height: 8),
                  _LocationCard(location: _device.currentLocation),
                ],
              ),
            ),
      bottomNavigationBar: _notFound
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton(
                      label: 'Buat Laporan',
                      icon: Icons.add_a_photo_outlined,
                      onPressed: _createReport,
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      label: 'Riwayat Laporan Perangkat',
                      icon: Icons.history,
                      variant: AppButtonVariant.secondary,
                      onPressed: _openHistory,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.device});

  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    final sticker = device.stickerUrl;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText(
                  device.code,
                  style: context.text.titleLarge,
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: device.isActive ? 'Aktif' : 'Nonaktif',
                tone: device.isActive ? StatusTone.success : StatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 8),
          InfoTile(label: 'Tipe', value: device.tipe?.name ?? ''),
          InfoTile(
            label: 'Kategori Dana',
            value: device.categoryDana?.name ?? '',
          ),
          if (sticker != null && sticker.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(
              child: NetworkThumb(
                url: sticker,
                size: 160,
                fit: BoxFit.contain,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => PhotoViewerPage(urls: [sticker]),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InactiveBanner extends StatelessWidget {
  const _InactiveBanner();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppCard(
      color: tokens.warningContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: tokens.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Perangkat nonaktif. Laporan tetap dapat dibuat.',
              style: context.text.bodyMedium?.copyWith(color: tokens.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location});

  final DeviceLocation? location;

  @override
  Widget build(BuildContext context) {
    final loc = location;
    final gedung = loc?.gedung;
    if (loc == null || (gedung == null && loc.location == null)) {
      return AppCard(
        child: Text(
          'Lokasi perangkat belum tercatat.',
          style: context.text.bodyMedium,
        ),
      );
    }

    final since = loc.since;
    final photo = gedung?.photoUrl;
    final point = loc.percentPoint;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoTile(
            label: 'Gedung',
            value: gedung?.label ?? '',
            icon: Icons.apartment_outlined,
          ),
          InfoTile(
            label: 'Koordinat pada denah',
            value: loc.coordinateLabel ?? '',
            icon: Icons.my_location_outlined,
          ),
          if (since != null)
            InfoTile(
              label: 'Sejak',
              value: formatDateTime(since.toLocal()),
              icon: Icons.schedule,
            ),
          if (photo != null && photo.isNotEmpty && point != null) ...[
            const SizedBox(height: 8),
            LocationMap(imageUrl: photo, percentPoint: point),
          ],
        ],
      ),
    );
  }
}
