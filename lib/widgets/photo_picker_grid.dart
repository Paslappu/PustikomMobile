import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qrscan/models/outbox_item.dart';
import 'package:qrscan/theme/app_tokens.dart';

enum ImageSourceKind { camera, gallery }

/// Bottom sheet asking where a photo comes from. Returns null when dismissed.
Future<ImageSourceKind?> showImageSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSourceKind>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Kamera'),
            onTap: () => Navigator.of(ctx).pop(ImageSourceKind.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galeri'),
            onTap: () => Navigator.of(ctx).pop(ImageSourceKind.gallery),
          ),
        ],
      ),
    ),
  );
}

/// Thumbnails of the photos of a draft report with remove buttons and an add
/// tile (hidden at [max]).
class PhotoPickerGrid extends StatelessWidget {
  const PhotoPickerGrid({
    super.key,
    required this.images,
    required this.resolve,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
    this.errorText,
    this.errorIndexes = const {},
    this.max = 5,
    this.enabled = true,
  });

  final List<OutboxImage> images;
  final File Function(OutboxImage image) resolve;

  /// A photo is being processed: the add tile shows a spinner and is disabled.
  final bool busy;
  final ValueChanged<ImageSourceKind> onAdd;
  final ValueChanged<OutboxImage> onRemove;
  final String? errorText;

  /// Positions in [images] that the server (or the pipeline) rejected.
  final Set<int> errorIndexes;
  final int max;
  final bool enabled;

  Future<void> _pickSource(BuildContext context) async {
    final kind = await showImageSourceSheet(context);
    if (kind != null) onAdd(kind);
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final scheme = context.colors;
    final canAdd = images.length < max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Foto', style: text.labelMedium)),
            Text('${images.length}/$max', style: text.labelMedium),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < images.length; i++)
              _PhotoTile(
                file: resolve(images[i]),
                hasError: errorIndexes.contains(i),
                onRemove: enabled && !busy ? () => onRemove(images[i]) : null,
              ),
            if (canAdd)
              _AddTile(
                busy: busy,
                onTap: enabled && !busy ? () => _pickSource(context) : null,
              ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: text.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.file,
    required this.hasError,
    required this.onRemove,
  });

  final File file;
  final bool hasError;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final radius = BorderRadius.circular(context.tokens.radiusMd);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: hasError ? Border.all(color: scheme.error, width: 2) : null,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Image.file(
              file,
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: scheme.inverseSurface.withValues(alpha: 0.7),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 16,
                  semanticLabel: 'Hapus foto',
                  color: scheme.onInverseSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final radius = BorderRadius.circular(context.tokens.radiusMd);
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Text('Tambah', style: context.text.labelSmall),
                  ],
                ),
        ),
      ),
    );
  }
}
