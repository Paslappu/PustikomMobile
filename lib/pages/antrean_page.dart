import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qrscan/models/outbox_item.dart';
import 'package:qrscan/pages/report_detail_page.dart';
import 'package:qrscan/pages/report_form_page.dart';
import 'package:qrscan/services/app_scope.dart';
import 'package:qrscan/services/app_services.dart';
import 'package:qrscan/theme/app_tokens.dart';
import 'package:qrscan/widgets/app_button.dart';
import 'package:qrscan/widgets/app_card.dart';
import 'package:qrscan/widgets/confirm_dialog.dart';
import 'package:qrscan/widgets/empty_state.dart';
import 'package:qrscan/widgets/outbox_tile.dart';
import 'package:qrscan/widgets/section_header.dart';

/// Queue of reports that are drafts, waiting to be sent, failed or sent.
class AntreanPage extends StatelessWidget {
  const AntreanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Antrean Pengiriman')),
      body: const OutboxListView(),
    );
  }
}

/// The queue list. Used by [AntreanPage] and by the "Antrean" tab of Laporan.
///
/// Sections: "Perlu perhatian" (failed), "Menunggu" (draft, pending,
/// uploading, waiting) and "Terkirim" (sent, collapsed).
class OutboxListView extends StatelessWidget {
  const OutboxListView({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: services.outbox,
      builder: (context, _) => ValueListenableBuilder<Map<String, double>>(
        valueListenable: services.outbox.progress,
        builder: (context, progress, _) =>
            _buildList(context, services, progress),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AppServices services,
    Map<String, double> progress,
  ) {
    final outbox = services.outbox;
    // Newest first inside each section.
    final items = outbox.items.reversed.toList();
    final failed = items.where((i) => i.status == OutboxStatus.failed).toList();
    final waiting = items
        .where(
          (i) =>
              i.status == OutboxStatus.draft ||
              i.status == OutboxStatus.pending ||
              i.status == OutboxStatus.uploading ||
              i.status == OutboxStatus.waiting,
        )
        .toList();
    final sent = items.where((i) => i.status == OutboxStatus.sent).toList();

    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.cloud_done_outlined,
        title: 'Tidak ada laporan di antrean.',
        message: 'Laporan yang belum terkirim akan muncul di sini.',
      );
    }

    Widget tile(OutboxItem item) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutboxTile(
        item: item,
        progress: progress[item.uuid],
        onSendNow: () => unawaited(outbox.drain()),
        onRetry: () => unawaited(outbox.retry(item.uuid)),
        onFix: () => _openForm(context, item.uuid),
        onDelete: () => _confirmDelete(context, services, item),
        onOpenSent: item.sentReportId == null
            ? null
            : () => _openSent(context, item.sentReportId!),
      ),
    );

    final canSend = items.any(
      (i) =>
          i.status == OutboxStatus.pending ||
          i.status == OutboxStatus.waiting ||
          i.status == OutboxStatus.failed,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (outbox.blockedByAuth) ...[
          const _AuthBlockedBanner(),
          const SizedBox(height: 12),
        ],
        if (canSend)
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Kirim semua',
              icon: Icons.cloud_upload_outlined,
              variant: AppButtonVariant.secondary,
              expanded: false,
              onPressed: () => unawaited(outbox.drain()),
            ),
          ),
        if (failed.isNotEmpty) ...[
          const SectionHeader(title: 'Perlu perhatian'),
          const SizedBox(height: 8),
          for (final item in failed) tile(item),
        ],
        if (waiting.isNotEmpty) ...[
          const SectionHeader(title: 'Menunggu'),
          const SizedBox(height: 8),
          for (final item in waiting) tile(item),
        ],
        if (sent.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              'Terkirim (${sent.length})',
              style: context.text.titleMedium,
            ),
            childrenPadding: const EdgeInsets.only(top: 8),
            children: [for (final item in sent) tile(item)],
          ),
      ],
    );
  }

  static void _openForm(BuildContext context, String uuid) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => ReportFormPage(uuid: uuid)));
  }

  static void _openSent(BuildContext context, int id) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => ReportDetailPage(id: id)));
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    AppServices services,
    OutboxItem item,
  ) async {
    final sent = item.status == OutboxStatus.sent;
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus dari antrean?',
      message: sent
          ? 'Catatan pengiriman ini dihapus dari perangkat. Laporan di server tidak terpengaruh.'
          : 'Laporan dan fotonya dihapus dari perangkat dan tidak akan dikirim.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok) return;
    await services.outbox.remove(item.uuid);
  }
}

class _AuthBlockedBanner extends StatelessWidget {
  const _AuthBlockedBanner();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppCard(
      color: tokens.warningContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: tokens.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pengiriman dijeda karena sesi berakhir. Masuk kembali untuk '
              'melanjutkan.',
              style: context.text.bodyMedium?.copyWith(color: tokens.warning),
            ),
          ),
        ],
      ),
    );
  }
}
