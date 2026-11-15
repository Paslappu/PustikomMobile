import 'package:flutter/material.dart';
import 'package:qrscan/widgets/confirm_dialog.dart';

/// Full-screen gallery: swipe between photos, pinch to zoom.
///
/// With [onDelete] the app bar offers "Hapus foto". The callback returns true
/// when the photo was removed; the viewer then drops it and closes after the
/// last one. The last photo of a report cannot be deleted (the server needs at
/// least one), so the action is disabled when only one photo is left and
/// [lastPhotoHint] is non-null.
class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    this.onDelete,
    this.lastPhotoHint = 'Foto terakhir tidak dapat dihapus.',
  });

  final List<String> urls;
  final int initialIndex;
  final Future<bool> Function(int index, String url)? onDelete;
  final String? lastPhotoHint;

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _controller;
  late List<String> _urls;
  late int _index;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _urls = List.of(widget.urls);
    _index = _urls.isEmpty ? 0 : widget.initialIndex.clamp(0, _urls.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final onDelete = widget.onDelete;
    if (onDelete == null || _deleting || _urls.length <= 1) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus foto?',
      message: 'Foto ini akan dihapus dari laporan.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    final removedIndex = _index;
    final deleted = await onDelete(removedIndex, _urls[removedIndex]);
    if (!mounted) return;
    setState(() {
      _deleting = false;
      if (deleted) {
        _urls.removeAt(removedIndex);
        if (_index >= _urls.length) _index = _urls.length - 1;
      }
    });
    if (deleted && _urls.isEmpty) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canDelete = widget.onDelete != null;
    final onlyOne = _urls.length <= 1;

    return Theme(
      data: Theme.of(
        context,
      ).copyWith(iconTheme: IconThemeData(color: scheme.onInverseSurface)),
      child: Scaffold(
        backgroundColor: scheme.scrim,
        appBar: AppBar(
          backgroundColor: scheme.scrim,
          foregroundColor: scheme.onInverseSurface,
          leading: IconButton(
            tooltip: 'Tutup',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _urls.isEmpty ? '' : '${_index + 1} / ${_urls.length}',
            style: TextStyle(color: scheme.onInverseSurface),
          ),
          actions: [
            if (canDelete)
              IconButton(
                tooltip: 'Hapus foto',
                icon: const Icon(Icons.delete_outline),
                onPressed: (onlyOne || _deleting) ? null : _delete,
              ),
          ],
        ),
        body: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: _urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _ZoomablePhoto(url: _urls[i]),
            ),
            if (canDelete && onlyOne && widget.lastPhotoHint != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: SafeArea(
                  child: Text(
                    widget.lastPhotoHint!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onInverseSurface,
                    ),
                  ),
                ),
              ),
            if (_deleting)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _ZoomablePhoto extends StatelessWidget {
  const _ZoomablePhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            final total = progress.expectedTotalBytes;
            return Center(
              child: CircularProgressIndicator(
                value: total == null
                    ? null
                    : progress.cumulativeBytesLoaded / total,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: scheme.onInverseSurface,
              ),
              const SizedBox(height: 8),
              Text(
                'Foto tidak dapat dimuat.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onInverseSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
