import 'package:flutter/material.dart';
import 'package:qrscan/models/perangkat_model.dart';
import 'package:qrscan/services/database_service.dart';
import 'package:qrscan/theme/app_tokens.dart';
import 'package:qrscan/widgets/app_button.dart';
import 'package:qrscan/widgets/app_card.dart';
import 'package:qrscan/widgets/app_snackbar.dart';
import 'package:qrscan/widgets/confirm_dialog.dart';
import 'package:qrscan/widgets/empty_state.dart';
import 'package:qrscan/widgets/loading_overlay.dart';

/// Read-only list of the notes saved on this phone by earlier versions of the
/// app. They can be exported to Excel or deleted, but not edited or created.
class LegacyNotesPage extends StatefulWidget {
  const LegacyNotesPage({super.key});

  @override
  State<LegacyNotesPage> createState() => _LegacyNotesPageState();
}

class _LegacyNotesPageState extends State<LegacyNotesPage> {
  final DatabaseService _db = DatabaseService.instance;

  List<PerangkatModel> _notes = const [];
  bool _loading = true;
  bool _busy = false;
  String? _busyMessage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _db.getPerangkat();
      data.sort((a, b) => b.id.compareTo(a.id));
      if (!mounted) return;
      setState(() {
        _notes = data;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Catatan lama tidak dapat dimuat.';
      });
    }
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _busyMessage = 'Menyiapkan file Excel...';
    });
    try {
      await _db.exportToExcel();
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Gagal mengekspor catatan.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAll() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus semua catatan lama?',
      message:
          'Seluruh catatan lokal akan dihapus dari perangkat ini dan tidak '
          'dapat dikembalikan. Ekspor ke Excel terlebih dahulu bila perlu.',
      confirmLabel: 'Hapus Semua',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _busyMessage = 'Menghapus catatan...';
    });
    try {
      for (final note in List.of(_notes)) {
        await _db.deletePerangkat(note.id);
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Gagal menghapus catatan.', isError: true);
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catatan Lama (Lokal)')),
      body: LoadingOverlay(
        isLoading: _busy,
        message: _busyMessage,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: _error!,
        actionLabel: 'Coba Lagi',
        onAction: () {
          setState(() => _loading = true);
          _load();
        },
      );
    }
    if (_notes.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Tidak ada catatan lama',
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _notes.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Text(
                  'Catatan yang disimpan di perangkat ini oleh versi aplikasi '
                  'sebelumnya. Catatan baru tidak lagi dibuat di sini; gunakan '
                  'Laporan.',
                  style: context.text.bodySmall,
                );
              }
              return _NoteCard(note: _notes[i - 1]);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppButton(
                  label: 'Ekspor ke Excel',
                  icon: Icons.file_download_outlined,
                  onPressed: _export,
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Hapus semua catatan lama',
                  icon: Icons.delete_outline,
                  variant: AppButtonVariant.danger,
                  onPressed: _deleteAll,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final PerangkatModel note;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final details = [
      if (note.gedung.isNotEmpty) note.gedung,
      'Port ${note.port}',
      if (note.tanggal.isNotEmpty) note.tanggal,
    ].join(' • ');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(note.nama, style: text.titleSmall),
          const SizedBox(height: 2),
          Text(details, style: text.bodySmall),
          if (note.location.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(note.location, style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}
