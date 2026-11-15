import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qrscan/models/report_model.dart';
import 'package:qrscan/services/api_exception.dart';
import 'package:qrscan/services/app_scope.dart';
import 'package:qrscan/services/location_service.dart';
import 'package:qrscan/services/report_service.dart';
import 'package:qrscan/theme/app_tokens.dart';
import 'package:qrscan/widgets/app_button.dart';
import 'package:qrscan/widgets/app_card.dart';
import 'package:qrscan/widgets/app_snackbar.dart';
import 'package:qrscan/widgets/app_text_field.dart';
import 'package:qrscan/widgets/captured_time_picker.dart';
import 'package:qrscan/widgets/gedung_picker_sheet.dart';
import 'package:qrscan/widgets/loading_overlay.dart';

/// Edits capture time, building, coordinates and notes of a server report.
/// Only changed fields are sent. Pops with the updated [DeviceReport].
class ReportEditPage extends StatefulWidget {
  const ReportEditPage({super.key, required this.report});

  final DeviceReport report;

  @override
  State<ReportEditPage> createState() => _ReportEditPageState();
}

class _ReportEditPageState extends State<ReportEditPage> {
  static const int _notesMax = 2000;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;

  late DateTime _capturedAt;
  int? _gedungId;
  String? _gedungLabel;

  bool _saving = false;
  bool _locating = false;
  int _locationRequest = 0;

  String? _banner;
  String? _timeError;
  String? _gedungError;
  String? _notesError;
  String? _latError;
  String? _lngError;

  @override
  void initState() {
    super.initState();
    final r = widget.report;
    _capturedAt = r.capturedAt.toLocal();
    _gedungId = r.gedungId;
    _gedungLabel = r.gedung?.label;
    _notesCtrl = TextEditingController(text: r.notes ?? '');
    _latCtrl = TextEditingController(text: _fmt(r.latitude));
    _lngCtrl = TextEditingController(text: _fmt(r.longitude));
  }

  @override
  void dispose() {
    _locationRequest++;
    _notesCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  static String _fmt(double? v) => v == null ? '' : v.toStringAsFixed(7);

  static double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  // ---- Fields ----

  Future<void> _pickTime() async {
    final picked = await pickCapturedAt(context, _capturedAt);
    if (picked == null || !mounted) return;
    setState(() {
      _capturedAt = picked;
      _timeError = null;
    });
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

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    final request = ++_locationRequest;
    setState(() => _locating = true);
    final fix = await AppScope.of(context).location.capture();
    if (!mounted || request != _locationRequest) return;
    setState(() => _locating = false);
    if (fix.ok) {
      _latCtrl.text = _fmt(fix.latitude);
      _lngCtrl.text = _fmt(fix.longitude);
      setState(() {
        _latError = null;
        _lngError = null;
      });
      return;
    }
    showAppSnackBar(context, _issueMessage(fix.issue), isError: true);
  }

  static String _issueMessage(LocationIssue? issue) => switch (issue) {
    LocationIssue.serviceDisabled => 'GPS nonaktif. Aktifkan layanan lokasi.',
    LocationIssue.denied => 'Izin lokasi ditolak.',
    LocationIssue.deniedForever =>
      'Izin lokasi ditolak permanen. Ubah di pengaturan aplikasi.',
    _ => 'Lokasi tidak tersedia. Coba lagi.',
  };

  void _clearCoordinates() {
    _locationRequest++;
    _latCtrl.clear();
    _lngCtrl.clear();
    setState(() {
      _locating = false;
      _latError = null;
      _lngError = null;
    });
  }

  static bool _differs(double? a, double? b) {
    if (a == null || b == null) return a != b;
    return (a - b).abs() > 1e-9;
  }

  // ---- Validation ----

  String? _validateLat(String? value) => _validateCoord(
    value,
    other: _lngCtrl.text,
    min: -90,
    max: 90,
    label: 'Lintang',
  );

  String? _validateLng(String? value) => _validateCoord(
    value,
    other: _latCtrl.text,
    min: -180,
    max: 180,
    label: 'Bujur',
  );

  String? _validateCoord(
    String? value, {
    required String other,
    required double min,
    required double max,
    required String label,
  }) {
    final text = (value ?? '').trim();
    final otherText = other.trim();
    if (text.isEmpty) {
      return otherText.isEmpty
          ? null
          : '$label wajib diisi bersama pasangannya.';
    }
    final number = _parse(text);
    if (number == null) return '$label harus berupa angka.';
    if (number < min || number > max) {
      return '$label harus antara ${min.toInt()} dan ${max.toInt()}.';
    }
    return null;
  }

  // ---- Save ----

  ReportPatch _buildPatch() {
    final r = widget.report;
    final notes = _notesCtrl.text.trim();
    final originalNotes = (r.notes ?? '').trim();
    final lat = _parse(_latCtrl.text);
    final lng = _parse(_lngCtrl.text);

    final timeChanged =
        _capturedAt.millisecondsSinceEpoch ~/ 1000 !=
        r.capturedAt.millisecondsSinceEpoch ~/ 1000;
    final coordsChanged =
        _differs(lat, r.latitude) || _differs(lng, r.longitude);

    return ReportPatch(
      capturedAt: timeChanged ? _capturedAt : null,
      setGedung: _gedungId != r.gedungId,
      gedungId: _gedungId,
      setCoords: coordsChanged,
      latitude: lat,
      longitude: lng,
      setNotes: notes != originalNotes,
      notes: notes.isEmpty ? null : notes,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _banner = null;
      _timeError = null;
      _gedungError = null;
      _notesError = null;
      _latError = null;
      _lngError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final patch = _buildPatch();
    if (patch.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final reports = AppScope.of(context).reports;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final updated = await reports.update(widget.report.id, patch);
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _applyError(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _banner = 'Terjadi kesalahan. Coba lagi.';
      });
    }
  }

  void _applyError(ApiException e) {
    switch (e.failure) {
      case ApiFailure.unauthorized:
        break; // The global handler signs out.
      case ApiFailure.validation:
        _timeError = e.firstError('captured_at');
        _gedungError = e.firstError('gedung_id');
        _notesError = e.firstError('notes');
        _latError = e.firstError('latitude');
        _lngError = e.firstError('longitude');
        final mapped =
            _timeError ?? _gedungError ?? _notesError ?? _latError ?? _lngError;
        if (mapped == null) _banner = e.message;
      case ApiFailure.network:
      case ApiFailure.timeout:
        _banner = 'Perubahan hanya dapat disimpan saat online. ${e.message}';
      case ApiFailure.forbidden:
        _banner = 'Anda tidak memiliki akses untuk mengubah laporan ini.';
      case ApiFailure.notFound:
        _banner = 'Laporan tidak ditemukan. Mungkin sudah dihapus.';
      default:
        _banner = e.message;
    }
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubah Laporan')),
      body: LoadingOverlay(
        isLoading: _saving,
        message: 'Menyimpan perubahan...',
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              if (_banner != null) ...[
                _EditErrorBanner(message: _banner!),
                const SizedBox(height: 12),
              ],
              AppCard(
                child: CapturedTimeRow(
                  capturedAt: _capturedAt,
                  errorText: _timeError,
                  onPick: _pickTime,
                  onUseNow: () => setState(() {
                    _capturedAt = DateTime.now();
                    _timeError = null;
                  }),
                ),
              ),
              const SizedBox(height: 16),
              _GedungTile(
                label: _gedungLabel,
                errorText: _gedungError,
                onTap: _pickGedung,
                onClear: () => setState(() {
                  _gedungId = null;
                  _gedungLabel = null;
                }),
              ),
              const SizedBox(height: 16),
              _CoordinatesSection(
                latCtrl: _latCtrl,
                lngCtrl: _lngCtrl,
                latError: _latError,
                lngError: _lngError,
                validateLat: _validateLat,
                validateLng: _validateLng,
                locating: _locating,
                onUseCurrent: _useCurrentLocation,
                onClear: _clearCoordinates,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _notesCtrl,
                label: 'Catatan',
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                inputFormatters: [LengthLimitingTextInputFormatter(_notesMax)],
                errorText: _notesError,
                onChanged: (_) => setState(() => _notesError = null),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _notesCtrl,
                  builder: (context, value, _) => Text(
                    '${value.text.length}/$_notesMax',
                    style: context.text.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Simpan Perubahan',
                icon: Icons.save_outlined,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditErrorBanner extends StatelessWidget {
  const _EditErrorBanner({required this.message});

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

class _GedungTile extends StatelessWidget {
  const _GedungTile({
    required this.label,
    required this.errorText,
    required this.onTap,
    required this.onClear,
  });

  final String? label;
  final String? errorText;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final scheme = context.colors;
    final selected = label != null && label!.isNotEmpty;
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
              suffixIcon: selected
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
      ],
    );
  }
}

class _CoordinatesSection extends StatelessWidget {
  const _CoordinatesSection({
    required this.latCtrl,
    required this.lngCtrl,
    required this.latError,
    required this.lngError,
    required this.validateLat,
    required this.validateLng,
    required this.locating,
    required this.onUseCurrent,
    required this.onClear,
  });

  final TextEditingController latCtrl;
  final TextEditingController lngCtrl;
  final String? latError;
  final String? lngError;
  final String? Function(String?) validateLat;
  final String? Function(String?) validateLng;
  final bool locating;
  final VoidCallback onUseCurrent;
  final VoidCallback onClear;

  static const _keyboard = TextInputType.numberWithOptions(
    decimal: true,
    signed: true,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Koordinat GPS', style: context.text.labelMedium),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: latCtrl,
                label: 'Lintang',
                hint: '-0.5412',
                keyboardType: _keyboard,
                validator: validateLat,
                errorText: latError,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: lngCtrl,
                label: 'Bujur',
                hint: '123.0589',
                keyboardType: _keyboard,
                validator: validateLng,
                errorText: lngError,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: locating ? null : onUseCurrent,
              icon: locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: const Text('Gunakan lokasi saat ini'),
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: context.colors.error,
              ),
              child: const Text('Hapus koordinat'),
            ),
          ],
        ),
      ],
    );
  }
}
