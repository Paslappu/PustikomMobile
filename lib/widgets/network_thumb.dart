import 'package:flutter/material.dart';
import 'package:qrscan/theme/app_tokens.dart';

/// Square network image with loading and error states.
class NetworkThumb extends StatelessWidget {
  const NetworkThumb({
    super.key,
    required this.url,
    this.size = 72,
    this.fit = BoxFit.cover,
    this.onTap,
  });

  /// Null or empty shows the placeholder icon.
  final String? url;
  final double size;
  final BoxFit fit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.tokens.radiusMd);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final address = url;

    final Widget content = (address == null || address.isEmpty)
        ? _Placeholder(size: size, icon: Icons.image_not_supported_outlined)
        : Image.network(
            address,
            width: size,
            height: size,
            fit: fit,
            cacheWidth: (size * dpr).round(),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                width: size,
                height: size,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) =>
                _Placeholder(size: size, icon: Icons.broken_image_outlined),
          );

    final thumb = ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: context.colors.surfaceContainerHighest,
        child: SizedBox(width: size, height: size, child: content),
      ),
    );
    if (onTap == null) return thumb;
    return GestureDetector(onTap: onTap, child: thumb);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size, required this.icon});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(
        icon,
        size: (size * 0.4).clamp(16.0, 40.0).toDouble(),
        color: context.colors.onSurfaceVariant,
      ),
    );
  }
}
