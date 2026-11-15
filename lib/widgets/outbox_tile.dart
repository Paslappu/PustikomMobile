import 'package:flutter/material.dart';
import 'package:qrscan/models/outbox_item.dart';
import 'package:qrscan/theme/app_tokens.dart';
import 'package:qrscan/utils/formatters.dart';
import 'package:qrscan/widgets/app_card.dart';
import 'package:qrscan/widgets/status_chip.dart';

/// Badge for the state of a queued report.
class OutboxStatusChip extends StatelessWidget {
  const OutboxStatusChip({super.key, required this.status});

  final OutboxStatus status;

  @override
  Widget build(BuildContext context) {
    final (String label, StatusTone tone) = switch (status) {
      OutboxStatus.draft => ('Draf', StatusTone.neutral),
      OutboxStatus.pending => ('Menunggu', StatusTone.info),
      OutboxStatus.uploading => ('Mengirim', StatusTone.info),
      OutboxStatus.waiting => ('Menunggu jaringan', StatusTone.warning),
      OutboxStatus.failed => ('Gagal', StatusTone.error),
      OutboxStatus.sent => ('Terkirim', StatusTone.success),
    };
    return StatusChip(label: label, tone: tone);
  }
}

/// One queued report: device, capture time, notes, state, last error, retry
/// time, upload progress and the actions that make sense for its state.
class OutboxTile extends StatelessWidget {
  const OutboxTile({
    super.key,
    required this.item,
    this.progress,
    this.onSendNow,
    this.onRetry,
    this.onFix,
    this.onDelete,
    this.onOpenSent,
  });

  final OutboxItem item;

  /// Upload progress 0..1 while uploading; null is indeterminate.
  final double? progress;
  final VoidCallback? onSendNow;
  final VoidCallback? onRetry;

  /// Opens the form to continue a draft or fix a failed report.
  final VoidCallback? onFix;
  final VoidCallback? onDelete;

  /// Opens the report on the server (sent items only).
  final VoidCallback? onOpenSent;

  bool get _isConflict => item.lastErrorCode == 409;

  bool get _needsFix =>
      item.lastErrorCode == 413 ||
      item.lastErrorCode == 422 ||
      item.lastErrorCode == 409;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final scheme = context.colors;
    final captured = DateTime.tryParse(item.capturedAt)?.toLocal();
    final notes = item.notes.trim();
    final error = item.lastError;
    final showError =
        error != null &&
        (item.status == OutboxStatus.failed ||
            item.status == OutboxStatus.waiting);
    final actions = _actions();
    final canOpen =
        item.status == OutboxStatus.sent && item.sentReportId != null;

    return AppCard(
      onTap: canOpen ? onOpenSent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.deviceLabel.isEmpty ? item.deviceCode : item.deviceLabel,
                  style: text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              OutboxStatusChip(status: item.status),
            ],
          ),
          if (captured != null) ...[
            const SizedBox(height: 2),
            Text(formatDateTime(captured), style: text.bodySmall),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              notes,
              style: text.bodySmall?.copyWith(color: scheme.onSurface),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text('${item.images.length} foto', style: text.bodySmall),
            ],
          ),
          if (item.status == OutboxStatus.uploading) ...[
            const SizedBox(height: 8),
            _UploadProgress(progress: progress),
          ],
          if (showError) ...[
            const SizedBox(height: 8),
            Text(error, style: text.bodySmall?.copyWith(color: scheme.error)),
          ],
          if (item.status == OutboxStatus.waiting) ...[
            const SizedBox(height: 4),
            Text(
              'Percobaan ke-${item.attempts}. Dicoba lagi sekitar '
              '${formatDateTime(DateTime.fromMillisecondsSinceEpoch(item.nextAttemptAt))}.',
              style: text.bodySmall,
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: actions),
          ],
        ],
      ),
    );
  }

  List<Widget> _actions() {
    Widget button(String label, VoidCallback? onTap, {bool danger = false}) {
      return Builder(
        builder: (context) => TextButton(
          onPressed: onTap,
          style: danger
              ? TextButton.styleFrom(foregroundColor: context.colors.error)
              : null,
          child: Text(label),
        ),
      );
    }

    switch (item.status) {
      case OutboxStatus.draft:
        return [
          button('Lanjutkan', onFix),
          button('Hapus', onDelete, danger: true),
        ];
      case OutboxStatus.pending:
        return [
          button('Kirim sekarang', onSendNow),
          button('Hapus', onDelete, danger: true),
        ];
      case OutboxStatus.uploading:
        return const [];
      case OutboxStatus.waiting:
        return [
          button('Coba lagi', onRetry),
          button('Hapus', onDelete, danger: true),
        ];
      case OutboxStatus.failed:
        return [
          if (!_needsFix) button('Coba lagi', onRetry),
          if (!_isConflict) button('Perbaiki', onFix),
          button('Hapus', onDelete, danger: true),
        ];
      case OutboxStatus.sent:
        return [button('Hapus', onDelete, danger: true)];
    }
  }
}

class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    final value = progress?.clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(child: LinearProgressIndicator(value: value)),
        if (value != null) ...[
          const SizedBox(width: 8),
          Text('${(value * 100).round()}%', style: context.text.bodySmall),
        ],
      ],
    );
  }
}
