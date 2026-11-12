class MediaItem {
  static const String statusPending = 'PENDING';
  static const String statusUploading = 'UPLOADING';
  static const String statusDone = 'DONE';
  static const String statusFailed = 'FAILED';
  static const String statusStashed = 'STASHED';

  final String filePath;
  String? fileHash;
  final String mimeType;
  final int dateTaken;
  final int fileSize;
  String status;
  int? telegramMessageId;
  String? errorReason;
  int retryCount;
  int updatedAt;
  int queueOrder;

  bool get isVideo {
    final lowerPath = filePath.toLowerCase();
    return mimeType.toLowerCase().contains('video') ||
        lowerPath.endsWith('.mp4') ||
        lowerPath.endsWith('.mov') ||
        lowerPath.endsWith('.mkv') ||
        lowerPath.endsWith('.webm') ||
        lowerPath.endsWith('.avi');
  }
  bool get isPhoto => !isVideo;

  MediaItem({
    required this.filePath,
    this.fileHash,
    required this.mimeType,
    required this.dateTaken,
    required this.fileSize,
    required this.status,
    this.telegramMessageId,
    this.errorReason,
    this.retryCount = 0,
    required this.updatedAt,
    this.queueOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'filePath': filePath,
      'fileHash': fileHash,
      'mimeType': mimeType,
      'dateTaken': dateTaken,
      'fileSize': fileSize,
      'status': status,
      'telegramMessageId': telegramMessageId,
      'errorReason': errorReason,
      'retryCount': retryCount,
      'updatedAt': updatedAt,
      'queueOrder': queueOrder,
    };
  }

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      filePath: map['filePath'],
      fileHash: map['fileHash'],
      mimeType: map['mimeType'],
      dateTaken: map['dateTaken'],
      fileSize: map['fileSize'],
      status: map['status'],
      telegramMessageId: map['telegramMessageId'],
      errorReason: map['errorReason'],
      retryCount: map['retryCount'],
      updatedAt: map['updatedAt'],
      queueOrder: map['queueOrder'] ?? 0,
    );
  }

  MediaItem copyWith({
    String? status,
    String? fileHash,
    int? telegramMessageId,
    String? errorReason,
    int? retryCount,
    int? updatedAt,
    int? queueOrder,
  }) {
    return MediaItem(
      filePath: filePath,
      fileHash: fileHash ?? this.fileHash,
      mimeType: mimeType,
      dateTaken: dateTaken,
      fileSize: fileSize,
      status: status ?? this.status,
      telegramMessageId: telegramMessageId ?? this.telegramMessageId,
      errorReason: errorReason ?? this.errorReason,
      retryCount: retryCount ?? this.retryCount,
      updatedAt: updatedAt ?? this.updatedAt,
      queueOrder: queueOrder ?? this.queueOrder,
    );
  }
}
