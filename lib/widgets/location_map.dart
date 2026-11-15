import 'package:flutter/material.dart';
import 'package:qrscan/theme/app_tokens.dart';

/// Building image with a dot at [percentPoint] (x, y in percent of the image).
class LocationMap extends StatelessWidget {
  const LocationMap({
    super.key,
    required this.imageUrl,
    this.percentPoint,
    this.dotColor,
  });

  final String imageUrl;
  final Offset? percentPoint;

  /// Defaults to the first colour of the token map palette.
  final Color? dotColor;

  static const double _dot = 18;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = dotColor ?? tokens.mapDotPalette.first;
    final point = percentPoint;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radiusMd),
      child: Image.network(
        imageUrl,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame == null && !wasSynchronouslyLoaded) {
            return const _MapPlaceholder(loading: true);
          }
          // The stack takes the size of the image, so the dot layer covers
          // exactly the rendered image and percentages map directly.
          return Stack(
            children: [
              child,
              if (point != null)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final x = point.dx.clamp(0.0, 100.0) / 100;
                      final y = point.dy.clamp(0.0, 100.0) / 100;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: constraints.maxWidth * x - _dot / 2,
                            top: constraints.maxHeight * y - _dot / 2,
                            child: Semantics(
                              label: 'Posisi perangkat pada denah',
                              child: _Dot(color: color),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            const _MapPlaceholder(loading: false),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      width: LocationMap._dot,
      height: LocationMap._dot,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.onPrimary, width: 3),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Denah tidak dapat dimuat',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
