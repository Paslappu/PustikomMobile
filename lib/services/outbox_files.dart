import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qrscan/models/outbox_item.dart';
import 'package:qrscan/services/image_pipeline.dart';

class OutboxFileException implements Exception {
  const OutboxFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Photo storage for queued reports: `<root>/<uuid>/<name>.jpg`.
///
/// Paths stored in the database are always relative to [root] because the iOS
/// container path changes between launches.
class OutboxFiles {
  OutboxFiles(this.root);

  final Directory root;

  static const int maxImages = 5;

  /// The folder for [uuid], created when missing.
  Directory draftDir(String uuid) {
    final dir = Directory(p.join(root.path, uuid));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  File resolve(String relPath) => File(p.join(root.path, relPath));

  /// The relative path to store for [file] inside [uuid]'s folder.
  String relPathFor(String uuid, File file) =>
      p.join(uuid, p.basename(file.path));

  /// Checks every photo of [item] right before upload and returns the files.
  Future<List<File>> validate(OutboxItem item) async {
    const message =
        'Foto hilang atau tidak valid. Perbaiki laporan atau hapus.';
    final images = [...item.images]
      ..sort((a, b) => a.position.compareTo(b.position));
    if (images.isEmpty || images.length > maxImages) {
      throw const OutboxFileException(message);
    }
    final files = <File>[];
    for (final image in images) {
      final file = resolve(image.relPath);
      try {
        if (!await file.exists()) throw const OutboxFileException(message);
        final length = await file.length();
        if (length <= 0 || length > ImagePipeline.maxBytes) {
          throw const OutboxFileException(message);
        }
        final raf = await file.open();
        final List<int> head;
        try {
          head = await raf.read(3);
        } finally {
          await raf.close();
        }
        if (!ImagePipeline.hasJpegMagic(head)) {
          throw const OutboxFileException(message);
        }
      } on FileSystemException {
        throw const OutboxFileException(message);
      }
      files.add(file);
    }
    return files;
  }

  Future<void> deleteDir(String uuid) async {
    final dir = Directory(p.join(root.path, uuid));
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  Future<void> deleteFile(String relPath) async {
    try {
      final file = resolve(relPath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Deletes folders that no row refers to and that are older than [minAge].
  Future<void> purgeOrphans(Set<String> knownUuids, Duration minAge) async {
    try {
      if (!await root.exists()) return;
      final cutoff = DateTime.now().subtract(minAge);
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = p.basename(entity.path);
        if (knownUuids.contains(name)) continue;
        final modified = (await entity.stat()).modified;
        if (modified.isBefore(cutoff)) {
          await entity.delete(recursive: true);
        }
      }
    } catch (_) {}
  }
}
