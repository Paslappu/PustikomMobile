import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageFormatException implements Exception {
  const ImageFormatException([this.message = 'Foto tidak dapat diproses.']);

  final String message;

  @override
  String toString() => message;
}

class ImageTooLargeException implements Exception {
  const ImageTooLargeException([
    this.message = 'Ukuran foto terlalu besar (maksimal 5 MB).',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Wraps the camera and gallery pickers so tests can fake them.
abstract class ImageSourceGateway {
  Future<File?> pickCamera();
  Future<List<File>> pickGallery({required int limit});

  /// Files lost when Android killed the activity during a pick. Empty on other
  /// platforms.
  Future<List<File>> retrieveLost();
}

class ImagePickerGateway implements ImageSourceGateway {
  ImagePickerGateway([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  // No maxWidth/maxHeight/imageQuality: the pipeline normalises the photo.

  @override
  Future<File?> pickCamera() async {
    final x = await _picker.pickImage(source: ImageSource.camera);
    return x == null ? null : File(x.path);
  }

  @override
  Future<List<File>> pickGallery({required int limit}) async {
    if (limit <= 0) return const [];
    if (limit == 1) {
      // pickMultiImage throws for a limit below 2.
      final x = await _picker.pickImage(source: ImageSource.gallery);
      return x == null ? const [] : [File(x.path)];
    }
    final picked = await _picker.pickMultiImage(limit: limit);
    return picked.take(limit).map((x) => File(x.path)).toList();
  }

  @override
  Future<List<File>> retrieveLost() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const [];
    }
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return const [];
      final files =
          response.files ?? [if (response.file != null) response.file!];
      return files.map((x) => File(x.path)).toList();
    } catch (_) {
      return const [];
    }
  }
}

abstract class ImageCompressor {
  /// Writes a JPEG to [targetPath]. Returns null when the plugin fails.
  Future<File?> compressToJpeg(
    File src,
    String targetPath, {
    required int quality,
    required int width,
    required int height,
  });
}

class FlutterImageCompressor implements ImageCompressor {
  const FlutterImageCompressor();

  @override
  Future<File?> compressToJpeg(
    File src,
    String targetPath, {
    required int quality,
    required int width,
    required int height,
  }) async {
    final out = await FlutterImageCompress.compressAndGetFile(
      src.path,
      targetPath,
      quality: quality,
      minWidth: width,
      minHeight: height,
      format: CompressFormat.jpeg,
      keepExif: false,
      autoCorrectionAngle: true,
    );
    return out == null ? null : File(out.path);
  }
}

typedef ImageSizeReader = Future<ui.Size> Function(File file);

/// Reads pixel dimensions without decoding the whole image.
Future<ui.Size> readImageSize(File file) async {
  final bytes = await file.readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    return ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble());
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
}

class ImagePipeline {
  ImagePipeline({
    ImageSourceGateway? source,
    ImageCompressor? compressor,
    ImageSizeReader? sizeReader,
    Future<Directory> Function()? tempDir,
    DateTime Function()? now,
  }) : source = source ?? ImagePickerGateway(),
       _compressor = compressor ?? const FlutterImageCompressor(),
       _readSize = sizeReader ?? readImageSize,
       _tempDir = tempDir ?? getTemporaryDirectory,
       _now = now ?? DateTime.now;

  final ImageSourceGateway source;
  final ImageCompressor _compressor;
  final ImageSizeReader _readSize;
  final Future<Directory> Function() _tempDir;
  final DateTime Function() _now;

  static const int maxBytes = 5 * 1024 * 1024;
  static const int maxSide = 1920;

  /// (quality, longest side) attempts, tried in order.
  static const List<(int, int)> _ladder = [
    (80, maxSide),
    (70, maxSide),
    (60, maxSide),
    (70, 1600),
    (70, 1280),
  ];

  /// Scales [w] x [h] down so the longest side is at most [maxSide].
  /// Never scales up.
  static ui.Size scaledSize(int w, int h, int maxSide) {
    final longest = math.max(w, h);
    if (longest <= 0 || longest <= maxSide) {
      return ui.Size(w.toDouble(), h.toDouble());
    }
    final scale = maxSide / longest;
    return ui.Size(
      math.max(1, (w * scale).round()).toDouble(),
      math.max(1, (h * scale).round()).toDouble(),
    );
  }

  static bool hasJpegMagic(List<int> head) =>
      head.length >= 3 && head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF;

  /// Converts [src] to a JPEG (long side <= 1920, <= 5 MB, no EXIF) inside
  /// [destDir]. Run it sequentially, one file at a time.
  Future<File> normalize(
    File src,
    Directory destDir, {
    int position = 0,
  }) async {
    try {
      final original = await _readSize(src);
      await destDir.create(recursive: true);
      final target = p.join(
        destDir.path,
        '${position}_${_now().millisecondsSinceEpoch}.jpg',
      );

      File? fallback;
      for (final (quality, side) in _ladder) {
        final size = scaledSize(
          original.width.round(),
          original.height.round(),
          side,
        );
        final out = await _compressor.compressToJpeg(
          src,
          target,
          quality: quality,
          width: size.width.round(),
          height: size.height.round(),
        );
        if (out == null) throw const ImageFormatException();

        final length = await out.length();
        if (length <= 0) throw const ImageFormatException();
        final head = await _readHead(out);
        if (!hasJpegMagic(head)) throw const ImageFormatException();
        if (length > maxBytes) continue;

        fallback = out;
        final actual = await _readSize(out);
        if (math.max(actual.width, actual.height) <= side + 2) {
          await _deleteTempSource(src);
          return out;
        }
      }

      if (fallback != null) {
        // Dimensions were off (for example EXIF rotation) but the file is a
        // valid JPEG within the size limit.
        await _deleteTempSource(src);
        return fallback;
      }
      throw const ImageTooLargeException();
    } on ImageFormatException {
      rethrow;
    } on ImageTooLargeException {
      rethrow;
    } catch (_) {
      throw const ImageFormatException();
    }
  }

  /// Files lost to an Android activity kill during a pick.
  Future<List<File>> recoverLost() => source.retrieveLost();

  Future<List<int>> _readHead(File f) async {
    final raf = await f.open();
    try {
      return await raf.read(3);
    } finally {
      await raf.close();
    }
  }

  Future<void> _deleteTempSource(File src) async {
    try {
      final temp = await _tempDir();
      if (p.isWithin(temp.path, src.path) && await src.exists()) {
        await src.delete();
      }
    } catch (_) {}
  }
}
