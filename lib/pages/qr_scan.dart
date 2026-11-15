import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide ScanWindowOverlay;
import 'package:qrscan/pages/device_detail_page.dart';
import 'package:qrscan/pages/devices_page.dart';
import 'package:qrscan/services/api_exception.dart';
import 'package:qrscan/services/app_scope.dart';
import 'package:qrscan/widgets/app_snackbar.dart';
import 'package:qrscan/widgets/empty_state.dart';
import 'package:qrscan/widgets/loading_overlay.dart';
import 'package:qrscan/widgets/manual_code_sheet.dart';
import 'package:qrscan/widgets/scan_overlay.dart';

/// Scanner tab. The host (`BaseHome`) builds it only while its tab is
/// selected, so the camera is released on other tabs.
class QrScan extends StatefulWidget {
  const QrScan({super.key});

  @override
  State<QrScan> createState() => _QrScanState();
}

class _QrScanState extends State<QrScan> with WidgetsBindingObserver {
  static const int _maxCodeLength = 500;

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );

  /// True while a scan is being resolved or another screen covers the camera.
  bool _handling = false;
  bool _looking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  // The widget only observes the app lifecycle itself when it creates its own
  // controller, so the camera is stopped and restarted here.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_handling) unawaited(_safeStart());
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        unawaited(_safeStop());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _safeStart() async {
    try {
      await _controller.start();
    } on MobileScannerException {
      // Shown through the scanner's errorBuilder (or retried on resume).
    }
  }

  Future<void> _safeStop() async {
    try {
      await _controller.stop();
    } on MobileScannerException {
      // Nothing to release.
    }
  }

  Future<void> _resume() async {
    if (!mounted) return;
    _handling = false;
    await _safeStart();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;
    _handling = true;

    if (raw.length > _maxCodeLength) {
      showAppSnackBar(context, 'Kode QR tidak valid.', isError: true);
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      _handling = false;
      return;
    }

    await _safeStop();
    unawaited(HapticFeedback.mediumImpact());
    if (!mounted) return;
    await _lookupAndOpen(raw);
    await _resume();
  }

  Future<void> _manualLookup() async {
    if (_handling) return;
    _handling = true;
    await _safeStop();
    if (!mounted) return;
    final raw = await showManualCodeSheet(context);
    if (!mounted) return;
    if (raw != null) await _lookupAndOpen(raw);
    await _resume();
  }

  Future<void> _openDevices() async {
    if (_handling) return;
    _handling = true;
    await _safeStop();
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const DevicesPage()));
    await _resume();
  }

  /// Looks the code up and opens the device. Offers a retry on network
  /// problems. Returns when the user is back on this screen or gave up.
  Future<void> _lookupAndOpen(String raw) async {
    final devices = AppScope.of(context).devices;
    while (true) {
      setState(() => _looking = true);
      try {
        final device = await devices.lookup(raw);
        if (!mounted) return;
        setState(() => _looking = false);
        await DeviceDetailPage.openFromScan(context, device);
        return;
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _looking = false);
        switch (e.failure) {
          case ApiFailure.unauthorized:
            return; // The global handler signs the user out.
          case ApiFailure.notFound:
            showAppSnackBar(
              context,
              'Perangkat tidak ditemukan untuk kode tersebut.',
              isError: true,
            );
            await Future<void>.delayed(const Duration(seconds: 1));
            return;
          case ApiFailure.network:
          case ApiFailure.timeout:
            final retry = await _askRetry(e.message);
            if (!retry || !mounted) return;
          default:
            showAppSnackBar(context, e.message, isError: true);
            await Future<void>.delayed(const Duration(seconds: 1));
            return;
        }
      }
    }
  }

  Future<bool> _askRetry(String message) async {
    final retry = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gagal mencari perangkat'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
    return retry ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LoadingOverlay(
      isLoading: _looking,
      message: 'Mencari perangkat...',
      child: ColoredBox(
        color: scheme.scrim,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final window = scanWindowFor(constraints.biggest);
            return Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  scanWindow: window,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => _CameraError(
                    onRetry: _safeStart,
                    onManual: _manualLookup,
                    onDevices: _openDevices,
                  ),
                ),
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _controller,
                  builder: (context, state, _) {
                    if (state.error != null) return const SizedBox.shrink();
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        if (state.isInitialized)
                          ScanWindowOverlay(window: window),
                        _TopBar(
                          state: state,
                          onTorch: _controller.toggleTorch,
                          onSwitchCamera: _controller.switchCamera,
                        ),
                        Positioned(
                          left: 24,
                          right: 24,
                          top: window.bottom + 16,
                          child: Text(
                            'Arahkan kamera ke kode QR perangkat',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onPrimary),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: _BottomActions(
                            onManual: _manualLookup,
                            onDevices: _openDevices,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.onTorch,
    required this.onSwitchCamera,
  });

  final MobileScannerState state;
  final Future<void> Function() onTorch;
  final Future<void> Function() onSwitchCamera;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final torchAvailable = state.torchState != TorchState.unavailable;
    final canSwitch = (state.availableCameras ?? 0) > 1;

    Widget action({
      required String tooltip,
      required IconData icon,
      required VoidCallback onPressed,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: scheme.scrim.withValues(alpha: 0.45),
          foregroundColor: scheme.onPrimary,
        ),
        icon: Icon(icon),
      );
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Pindai QR',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: scheme.onPrimary),
              ),
            ),
            if (torchAvailable)
              action(
                tooltip: 'Senter',
                icon: state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
                onPressed: () => unawaited(_guard(onTorch)),
              ),
            if (canSwitch) ...[
              const SizedBox(width: 8),
              action(
                tooltip: 'Ganti Kamera',
                icon: Icons.cameraswitch_outlined,
                onPressed: () => unawaited(_guard(onSwitchCamera)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on MobileScannerException {
      // The scanner reports unusable states through its own error state.
    }
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.onManual, required this.onDevices});

  final VoidCallback onManual;
  final VoidCallback onDevices;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = OutlinedButton.styleFrom(
      foregroundColor: scheme.onPrimary,
      side: BorderSide(color: scheme.onPrimary.withValues(alpha: 0.7)),
      backgroundColor: scheme.scrim.withValues(alpha: 0.35),
    );
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: style,
            onPressed: onManual,
            icon: const Icon(Icons.keyboard_outlined),
            label: const Text('Ketik kode'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: style,
            onPressed: onDevices,
            icon: const Icon(Icons.list_alt_outlined),
            label: const Text('Daftar Perangkat'),
          ),
        ),
      ],
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({
    required this.onRetry,
    required this.onManual,
    required this.onDevices,
  });

  final Future<void> Function() onRetry;
  final VoidCallback onManual;
  final VoidCallback onDevices;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyState(
                icon: Icons.no_photography_outlined,
                title: 'Kamera tidak dapat digunakan',
                message:
                    'Izinkan akses kamera di Pengaturan perangkat, lalu coba '
                    'lagi. Anda juga dapat mengetik kode perangkat.',
                actionLabel: 'Coba Lagi',
                onAction: () => unawaited(onRetry()),
              ),
              TextButton.icon(
                onPressed: onManual,
                icon: const Icon(Icons.keyboard_outlined),
                label: const Text('Ketik kode manual'),
              ),
              TextButton.icon(
                onPressed: onDevices,
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text('Daftar Perangkat'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
