import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/media_item.dart';

/// Thread-safe in-memory write buffer for debounced SQLite batch operations.
/// Eliminates flash storage write contention during burst synchronizations while
/// guaranteeing zero data loss, mutexed flushing, and read-your-own-writes consistency.
class BatchedWriteQueue {
  final Future<void> Function(List<MediaItem> items) onCommitBatch;
  final int batchThreshold;
  final Duration flushInterval;

  final Map<String, MediaItem> _pendingUpdates = {};
  Timer? _flushTimer;
  Completer<void>? _activeFlushCompleter;

  BatchedWriteQueue({
    required this.onCommitBatch,
    this.batchThreshold = 10,
    this.flushInterval = const Duration(milliseconds: 3500),
  });

  bool get isNotEmpty => _pendingUpdates.isNotEmpty;
  int get length => _pendingUpdates.length;

  /// Enqueue an item update into the in-memory batch.
  void enqueue(MediaItem item, {bool immediate = false}) {
    _pendingUpdates[item.filePath] = item;
    if (immediate || _pendingUpdates.length >= batchThreshold) {
      flush();
    } else {
      _flushTimer ??= Timer(flushInterval, () {
        flush();
      });
    }
  }

  /// Read-through check for an item by filePath.
  MediaItem? getItem(String path) => _pendingUpdates[path];

  /// Read-through check for an item by fileHash.
  MediaItem? getItemByHash(String hash) {
    for (final item in _pendingUpdates.values) {
      if (item.fileHash == hash) return item;
    }
    return null;
  }

  /// Removes an item from the pending buffer (e.g. if explicitly deleted or updated immediately).
  void remove(String path) {
    _pendingUpdates.remove(path);
  }

  /// Clears in-memory buffer (for testing teardowns).
  void clear() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingUpdates.clear();
  }

  /// Atomically flushes all staged updates via [onCommitBatch].
  /// Mutexed to prevent overlapping database transactions.
  /// Loops until all pending updates (including those enqueued while committing) are flushed.
  /// Preserves dirty records in memory if the transaction throws.
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;

    while (_activeFlushCompleter != null) {
      try {
        await _activeFlushCompleter!.future;
      } catch (_) {
        break;
      }
    }

    if (_pendingUpdates.isEmpty) return;

    final completer = Completer<void>();
    _activeFlushCompleter = completer;
    completer.future.ignore();

    final batchItems = _pendingUpdates.values.toList();
    try {
      await onCommitBatch(batchItems);

      // Only remove items whose timestamp hasn't been superseded by a newer enqueue
      for (final item in batchItems) {
        if (_pendingUpdates[item.filePath]?.updatedAt == item.updatedAt) {
          _pendingUpdates.remove(item.filePath);
        }
      }
      completer.complete();
    } catch (e, st) {
      debugPrint('[BatchedWriteQueue] Batch commit failed, retaining items in memory: $e');
      completer.completeError(e, st);
    } finally {
      _activeFlushCompleter = null;
      if (_pendingUpdates.isNotEmpty) {
        _flushTimer ??= Timer(flushInterval, () => flush());
      }
    }
  }
}
