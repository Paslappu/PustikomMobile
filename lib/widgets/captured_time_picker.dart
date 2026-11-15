import 'package:flutter/material.dart';
import 'package:qrscan/utils/formatters.dart';

/// "15 Nov 2026, 09:30 (+08:00)" for a local time.
String describeCapturedAt(DateTime local) {
  final iso = formatIsoWithOffset(local);
  final offset = iso.substring(iso.length - 6);
  return '${formatDateTime(local)} ($offset)';
}

/// Asks for a date and then a time. The future is not allowed: a later time on
/// today is clamped to now. Returns null when the user cancels.
Future<DateTime?> pickCapturedAt(BuildContext context, DateTime initial) async {
  final now = DateTime.now();
  final start = initial.isAfter(now) ? now : initial;
  final date = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: DateTime(now.year - 5),
    lastDate: now,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(start),
  );
  if (time == null) return null;
  final picked = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  return picked.isAfter(DateTime.now()) ? DateTime.now() : picked;
}

/// Read-only row with the capture time and, when [onPick] is set, buttons to
/// change it.
class CapturedTimeRow extends StatelessWidget {
  const CapturedTimeRow({
    super.key,
    required this.capturedAt,
    this.errorText,
    this.onPick,
    this.onUseNow,
    this.label = 'Waktu pengambilan',
  });

  final DateTime capturedAt;
  final String? errorText;
  final VoidCallback? onPick;
  final VoidCallback? onUseNow;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final editable = onPick != null || onUseNow != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    describeCapturedAt(capturedAt),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
        if (editable) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              if (onPick != null)
                TextButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                  label: const Text('Ubah waktu'),
                ),
              if (onUseNow != null)
                TextButton.icon(
                  onPressed: onUseNow,
                  icon: const Icon(Icons.update, size: 18),
                  label: const Text('Gunakan waktu sekarang'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
