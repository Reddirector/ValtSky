import 'dart:io';

class ValidationResult {
  final bool isValid;
  final String? error;
  final String? detectedType;
  final bool isMalicious;

  const ValidationResult({
    required this.isValid,
    this.error,
    this.detectedType,
    this.isMalicious = false,
  });

  factory ValidationResult.success(String detectedType) => ValidationResult(
        isValid: true,
        detectedType: detectedType,
      );

  factory ValidationResult.failure(String error, {bool isMalicious = false}) => ValidationResult(
        isValid: false,
        error: error,
        isMalicious: isMalicious,
      );
}

class UrlValidationResult {
  final bool isValid;
  final String? error;

  const UrlValidationResult({required this.isValid, this.error});

  factory UrlValidationResult.valid() => const UrlValidationResult(isValid: true);
  factory UrlValidationResult.invalid(String error) => UrlValidationResult(isValid: false, error: error);
}

/// Enterprise cybersecurity validation engine for ValtSky.
/// Enforces magic byte verification, payload scanning, path traversal defense, and SSRF prevention.
class FileSecurityGuard {
  // EICAR Standard Antivirus Test signature
  static const String _eicarSig = 'X5O!P%@AP[4\\PZX54(P^)7CC)7}\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\$H+H*';

  /// Validates physical file integrity, magic bytes, and scans for disguised malicious payloads
  static Future<ValidationResult> validateFile(File file) async {
    try {
      if (!await file.exists()) {
        return ValidationResult.failure('File does not exist on storage');
      }

      final length = await file.length();
      if (length == 0) {
        return ValidationResult.failure('Empty file (0 bytes rejected)');
      }

      // Telegram maximum absolute upload limit (2 GB for local bot server)
      if (length > 2 * 1024 * 1024 * 1024) {
        return ValidationResult.failure('File exceeds 2 GB Telegram ceiling');
      }

      // Check filename sanitization
      final rawName = file.path.split('/').last.split('\\').last;
      if (rawName.contains('\x00') || rawName.contains('..')) {
        return ValidationResult.failure('Path traversal or null-byte anomaly detected in filename', isMalicious: true);
      }

      // Read initial header bytes (up to 512 bytes)
      final raf = await file.open(mode: FileMode.read);
      final readLength = length < 512 ? length : 512;
      final header = await raf.read(readLength);
      await raf.close();

      return validateBytes(header, rawName, totalLength: length);
    } catch (e) {
      return ValidationResult.failure('Security inspection error: ${e.toString()}');
    }
  }

  /// Inspects raw header bytes for signatures, malicious headers, and media magic bytes
  static ValidationResult validateBytes(List<int> header, String fileName, {int? totalLength}) {
    if (header.isEmpty) {
      return ValidationResult.failure('Empty byte payload');
    }

    // 1. Scan for EICAR Antivirus Test Signature
    final headerString = String.fromCharCodes(header.where((b) => b >= 32 && b <= 126));
    if (headerString.contains(_eicarSig) || headerString.contains('EICAR-STANDARD-ANTIVIRUS-TEST-FILE')) {
      return ValidationResult.failure(
        'Malicious payload signature detected (EICAR Test Signature match)',
        isMalicious: true,
      );
    }

    // 2. Check for Executable Binary Headers (CWE-434 Defense)
    // ELF Header (Linux / Android binary) -> 7F 45 4C 46
    if (header.length >= 4 &&
        header[0] == 0x7F &&
        header[1] == 0x45 &&
        header[2] == 0x4C &&
        header[3] == 0x46) {
      return ValidationResult.failure(
        'Disguised executable detected: Linux/Android ELF binary header',
        isMalicious: true,
      );
    }

    // Windows PE / DOS Executable -> 4D 5A ("MZ")
    if (header.length >= 2 && header[0] == 0x4D && header[1] == 0x5A) {
      return ValidationResult.failure(
        'Disguised executable detected: Windows DOS/PE (MZ) executable header',
        isMalicious: true,
      );
    }

    // Java Bytecode / Mach-O Universal -> CA FE BA BE
    if (header.length >= 4 &&
        header[0] == 0xCA &&
        header[1] == 0xFE &&
        header[2] == 0xBA &&
        header[3] == 0xBE) {
      return ValidationResult.failure(
        'Disguised binary detected: Java class compiled bytecode / Mach-O universal header',
        isMalicious: true,
      );
    }

    // Mach-O Native Executable (32-bit / 64-bit)
    if (header.length >= 4 &&
        ((header[0] == 0xFE && header[1] == 0xED && header[2] == 0xFA && (header[3] == 0xCE || header[3] == 0xCF)) ||
         ((header[0] == 0xCE || header[0] == 0xCF) && header[1] == 0xFA && header[2] == 0xED && header[3] == 0xFE))) {
      return ValidationResult.failure(
        'Disguised binary detected: Apple Mach-O executable header',
        isMalicious: true,
      );
    }

    // WebAssembly Binary -> \0asm (00 61 73 6D)
    if (header.length >= 4 &&
        header[0] == 0x00 &&
        header[1] == 0x61 &&
        header[2] == 0x73 &&
        header[3] == 0x6D) {
      return ValidationResult.failure(
        'Disguised binary detected: WebAssembly compiled binary header',
        isMalicious: true,
      );
    }

    // Disguised ZIP / Archive Header -> PK.. (50 4B 03 04)
    if (header.length >= 4 &&
        header[0] == 0x50 &&
        header[1] == 0x4B &&
        ((header[2] == 0x03 && header[3] == 0x04) || (header[2] == 0x05 && header[3] == 0x06))) {
      return ValidationResult.failure(
        'Disguised archive detected: ZIP/JAR compressed archive header',
        isMalicious: true,
      );
    }

    // Shell Script Shebang -> #! (23 21)
    if (header.length >= 2 && header[0] == 0x23 && header[1] == 0x21) {
      return ValidationResult.failure(
        'Disguised executable script detected: Unix Shebang (#!) header',
        isMalicious: true,
      );
    }

    // 3. Verify Media Magic Bytes
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

    // JPEG -> FF D8 FF
    if (header.length >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) {
      return ValidationResult.success('image/jpeg');
    }

    // PNG -> 89 50 4E 47 0D 0A 1A 0A
    if (header.length >= 8 &&
        header[0] == 0x89 &&
        header[1] == 0x50 &&
        header[2] == 0x4E &&
        header[3] == 0x47 &&
        header[4] == 0x0D &&
        header[5] == 0x0A &&
        header[6] == 0x1A &&
        header[7] == 0x0A) {
      return ValidationResult.success('image/png');
    }

    // GIF -> 'GIF87a' or 'GIF89a'
    if (header.length >= 6) {
      final magic6 = String.fromCharCodes(header.sublist(0, 6));
      if (magic6 == 'GIF87a' || magic6 == 'GIF89a') {
        return ValidationResult.success('image/gif');
      }
    }

    // WebP -> 'RIFF' .... 'WEBP'
    if (header.length >= 12) {
      final riff = String.fromCharCodes(header.sublist(0, 4));
      final webp = String.fromCharCodes(header.sublist(8, 12));
      if (riff == 'RIFF' && webp == 'WEBP') {
        return ValidationResult.success('image/webp');
      }
    }

    // MP4 / QuickTime / MOV -> Offset 4 contains 'ftyp', 'moov', 'mdat', 'wide'
    if (header.length >= 8) {
      final boxType = String.fromCharCodes(header.sublist(4, 8));
      if (boxType == 'ftyp' || boxType == 'moov' || boxType == 'mdat' || boxType == 'wide') {
        return ValidationResult.success('video/mp4');
      }
    }

    // Matroska / MKV / WebM -> 1A 45 DF A3
    if (header.length >= 4 &&
        header[0] == 0x1A &&
        header[1] == 0x45 &&
        header[2] == 0xDF &&
        header[3] == 0xA3) {
      return ValidationResult.success('video/x-matroska');
    }

    // AVI -> 'RIFF' .... 'AVI '
    if (header.length >= 12) {
      final riff = String.fromCharCodes(header.sublist(0, 4));
      final avi = String.fromCharCodes(header.sublist(8, 12));
      if (riff == 'RIFF' && avi == 'AVI ') {
        return ValidationResult.success('video/x-msvideo');
      }
    }

    // If extension claims to be media but magic bytes do not match:
    const mediaExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'mkv', 'avi'};
    if (mediaExtensions.contains(ext)) {
      return ValidationResult.failure(
        'Header mismatch: File claims to be ".$ext" but lacks valid image/video magic bytes',
        isMalicious: true,
      );
    }

    // Generic binary / document fallback
    return ValidationResult.success('application/octet-stream');
  }

  /// Sanitizes raw filename to prevent path traversal, control character injection, and terminal exploits
  static String sanitizeFileName(String rawName) {
    var clean = rawName.split('/').last.split('\\').last;
    // Decode percent encoding to prevent double-encoding bypasses (e.g. %2e%2e%2f)
    try {
      if (clean.contains('%')) {
        clean = Uri.decodeComponent(clean);
      }
    } catch (_) {}
    clean = clean.split('/').last.split('\\').last;
    // Strip directory traversal sequences
    clean = clean.replaceAll('..', '');
    // Strip null bytes and control characters
    clean = clean.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    // Strip shell separators and command injection characters
    clean = clean.replaceAll(';', '_').replaceAll('&', '_').replaceAll('|', '_').replaceAll(r'$', '_').replaceAll('`', '_');
    if (clean.isEmpty) {
      clean = 'media_${DateTime.now().millisecondsSinceEpoch}';
    }
    return clean;
  }

  /// Sanitizes text for Telegram MarkdownV2 entity parsing to prevent formatting breaks and entity injection
  static String escapeTelegramMarkdown(String text) {
    // Characters to escape in Telegram MarkdownV2: _ * [ ] ( ) ~ ` > # + - = | { } . !
    return text.replaceAllMapped(
      RegExp(r'[_*\[\]()~`>#+\-=|{}.!\\]'),
      (match) => '\\${match[0]}',
    );
  }

  /// Validates Custom API Endpoint URL to block SSRF, non-HTTPS protocols, and metadata IP targets
  static UrlValidationResult validateApiUrl(String url) {
    if (url.trim().isEmpty) {
      return UrlValidationResult.invalid('API URL cannot be empty');
    }

    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return UrlValidationResult.invalid('Invalid URL syntax');
    }

    // Scheme check
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return UrlValidationResult.invalid('Only HTTP/HTTPS protocols are permitted');
    }

    final host = uri.host.toLowerCase();

    // SSRF Cloud Metadata Guard
    if (host == '169.254.169.254' || host.startsWith('169.254.') || host == 'metadata.google.internal') {
      return UrlValidationResult.invalid('SSRF Security Alert: Cloud metadata access is prohibited');
    }

    // SSRF Localhost Port Scanning Guard on plain HTTP
    final isLocalhost = host == 'localhost' || host == '127.0.0.1' || host == '::1';
    if (uri.scheme == 'http' && !isLocalhost) {
      return UrlValidationResult.invalid('Remote servers must use secure HTTPS (plain HTTP is only permitted on localhost)');
    }

    // Port range check
    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
      return UrlValidationResult.invalid('Port must be between 1 and 65535');
    }

    return UrlValidationResult.valid();
  }

  /// Masks sensitive Telegram Bot Token for safe display and logging
  static String maskToken(String token) {
    if (token.isEmpty) return 'Not configured';
    final parts = token.split(':');
    if (parts.length == 2 && parts[0].isNotEmpty && parts[1].length > 6) {
      final botId = parts[0];
      final secret = parts[1];
      return '$botId:${secret.substring(0, 3)}...${secret.substring(secret.length - 3)}';
    }
    if (token.length > 8) {
      return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
    }
    return '••••••••';
  }
}
