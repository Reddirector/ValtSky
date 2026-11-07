class MediaBreakdown {
  final int pendingPhotos;
  final int pendingVideos;
  final int syncedPhotos;
  final int syncedVideos;
  final int failedPhotos;
  final int failedVideos;
  final int totalCount;
  final int oversizedCount;

  const MediaBreakdown({
    this.pendingPhotos = 0,
    this.pendingVideos = 0,
    this.syncedPhotos = 0,
    this.syncedVideos = 0,
    this.failedPhotos = 0,
    this.failedVideos = 0,
    this.totalCount = 0,
    this.oversizedCount = 0,
  });

  int get totalPending => pendingPhotos + pendingVideos;
  int get totalSynced => syncedPhotos + syncedVideos;
  int get totalFailed => failedPhotos + failedVideos;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaBreakdown &&
          runtimeType == other.runtimeType &&
          pendingPhotos == other.pendingPhotos &&
          pendingVideos == other.pendingVideos &&
          syncedPhotos == other.syncedPhotos &&
          syncedVideos == other.syncedVideos &&
          failedPhotos == other.failedPhotos &&
          failedVideos == other.failedVideos &&
          totalCount == other.totalCount &&
          oversizedCount == other.oversizedCount;

  @override
  int get hashCode => Object.hash(
        pendingPhotos,
        pendingVideos,
        syncedPhotos,
        syncedVideos,
        failedPhotos,
        failedVideos,
        totalCount,
        oversizedCount,
      );

  @override
  String toString() {
    return 'MediaBreakdown(pendingPhotos: $pendingPhotos, pendingVideos: $pendingVideos, syncedPhotos: $syncedPhotos, syncedVideos: $syncedVideos, failedPhotos: $failedPhotos, failedVideos: $failedVideos, total: $totalCount, oversized: $oversizedCount)';
  }
}
