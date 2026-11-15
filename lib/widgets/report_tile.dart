import 'package:flutter/material.dart';
import 'package:qrscan/models/report_model.dart';
import 'package:qrscan/theme/app_tokens.dart';
import 'package:qrscan/utils/formatters.dart';
import 'package:qrscan/widgets/app_card.dart';
import 'package:qrscan/widgets/network_thumb.dart';

/// One row of a report list: first photo, device code, building, capture time,
/// notes snippet, photo count and (for admins) the author.
class ReportTile extends StatelessWidget {
  const ReportTile({
    super.key,
    required this.report,
    this.onTap,
    this.showUser = false,
  });

  final DeviceReport report;
  final VoidCallback? onTap;

  /// Show the author's name (used when the current user is an admin).
  final bool showUser;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final text = context.text;
    final notes = report.notes?.trim() ?? '';
    final gedung = report.gedung?.label;
    final user = report.user?.name;

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetworkThumb(
            url: report.images.isEmpty ? null : report.images.first.url,
            size: 64,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.device?.code ?? 'Perangkat #${report.deviceId}',
                  style: text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (gedung != null && gedung.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    gedung,
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  formatDateTime(report.capturedAt.toLocal()),
                  style: text.bodySmall,
                ),
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
                    Text('${report.images.length} foto', style: text.bodySmall),
                    if (showUser && user != null && user.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          user,
                          style: text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
