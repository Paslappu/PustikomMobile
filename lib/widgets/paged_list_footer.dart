import 'package:flutter/material.dart';
import 'package:qrscan/widgets/app_button.dart';

/// Last row of an infinite list: spinner while loading, an error with retry,
/// or an end-of-list note.
class PagedListFooter extends StatelessWidget {
  const PagedListFooter({
    super.key,
    required this.isLoading,
    required this.hasMore,
    this.errorMessage,
    this.onRetry,
  });

  final bool isLoading;
  final bool hasMore;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget child;
    if (isLoading) {
      child = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else if (errorMessage != null) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            errorMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null)
            AppButton(
              label: 'Coba Lagi',
              variant: AppButtonVariant.text,
              expanded: false,
              onPressed: onRetry,
            ),
        ],
      );
    } else if (!hasMore) {
      child = Text('Akhir daftar', style: theme.textTheme.bodySmall);
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: child),
    );
  }
}
