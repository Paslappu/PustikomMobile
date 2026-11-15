import 'package:qrscan/models/outbox_item.dart';

/// Persistence for queued reports. `DatabaseService` is the real
/// implementation.
abstract class OutboxStore {
  Future<void> insert(OutboxItem item);

  /// Updates the row columns only (not the images).
  Future<void> update(OutboxItem item);

  /// Replaces all image rows of [uuid].
  Future<void> replaceImages(String uuid, List<OutboxImage> images);

  Future<OutboxItem?> get(String uuid);

  /// Items of [userId] with their images, oldest first.
  Future<List<OutboxItem>> listForUser(int userId);

  /// Removes the row and its images in one transaction.
  Future<void> delete(String uuid);

  /// Crash recovery: `uploading` rows become `pending`. Returns the count.
  Future<int> resetUploadingToPending();

  /// Every uuid in the table, for all users. Used to find orphaned photo
  /// folders without touching other accounts' queues.
  Future<Set<String>> allUuids();
}
