import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, text, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final VoidCallback? handler = isLoading ? null : onPressed;
    final Widget? leading = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : (icon != null ? Icon(icon, size: 20) : null);
    final text = Text(label);

    final Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = leading == null
            ? FilledButton(onPressed: handler, child: text)
            : FilledButton.icon(onPressed: handler, icon: leading, label: text);
      case AppButtonVariant.secondary:
        button = leading == null
            ? OutlinedButton(onPressed: handler, child: text)
            : OutlinedButton.icon(
                onPressed: handler,
                icon: leading,
                label: text,
              );
      case AppButtonVariant.text:
        button = leading == null
            ? TextButton(onPressed: handler, child: text)
            : TextButton.icon(onPressed: handler, icon: leading, label: text);
      case AppButtonVariant.danger:
        final style = OutlinedButton.styleFrom(
          foregroundColor: scheme.error,
          side: BorderSide(color: scheme.error),
        );
        button = leading == null
            ? OutlinedButton(onPressed: handler, style: style, child: text)
            : OutlinedButton.icon(
                onPressed: handler,
                style: style,
                icon: leading,
                label: text,
              );
    }

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
