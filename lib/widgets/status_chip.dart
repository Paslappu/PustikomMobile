import 'package:flutter/material.dart';
import 'package:qrscan/theme/app_tokens.dart';

enum StatusTone { success, warning, error, info, neutral }

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
  });

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = context.colors;
    final (Color bg, Color fg) = switch (tone) {
      StatusTone.success => (tokens.successContainer, tokens.success),
      StatusTone.warning => (tokens.warningContainer, tokens.warning),
      StatusTone.error => (tokens.dangerContainer, tokens.danger),
      StatusTone.info => (tokens.infoContainer, tokens.info),
      StatusTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
