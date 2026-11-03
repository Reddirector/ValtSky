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
    );
  }

  MediaItem copyWith({
    String? status,
    String? fileHash,
    int? telegramMessageId,
    String? errorReason,
    int? retryCount,
    int? updatedAt,
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
    );
  }
}
