import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtsky_flutter/data/models/media_item.dart';
import 'package:valtsky_flutter/util/file_security_guard.dart';
import 'package:valtsky_flutter/util/file_utils.dart';

void main() {
  group('🛡️ ValtSky Strict Senior Cybersecurity & Robustness Attack Suite', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('valtsky_strict_audit_');
    });

    tearDownAll(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('TEST 1: Advanced Path Traversal, URL-Encoded Escapes, & Shell Injections', () async {
      const maliciousNames = [
        '../../../../etc/passwd',
        '..\\..\\windows\\system32\\cmd.exe',
        '%2e%2e%2f%2e%2e%2fetc%2fshadow',
        'photo;rm -rf /;test.jpg',
        'img\$(cat /etc/passwd).png',
        'test`whoami`evil.jpg',
        'file\x00hidden.exe.jpg',
        'control\n\r\tchars.png',
        'normal_photo.jpg',
      ];

      for (final rawName in maliciousNames) {
        final sanitized = FileSecurityGuard.sanitizeFileName(rawName);
        expect(sanitized.contains('/'), isFalse, reason: 'Slash must be stripped');
        expect(sanitized.contains('\\'), isFalse, reason: 'Backslash must be stripped');
        expect(sanitized.contains('..'), isFalse, reason: 'Double dots must be stripped');
        expect(sanitized.contains(';'), isFalse, reason: 'Semicolon must be stripped');
        expect(sanitized.contains('\$'), isFalse, reason: 'Dollar sign must be stripped');
        expect(sanitized.contains('`'), isFalse, reason: 'Backtick must be stripped');
        expect(sanitized.contains('\x00'), isFalse, reason: 'Null byte must be stripped');
        expect(sanitized.isNotEmpty, isTrue, reason: 'Sanitized name must never be empty');
      }
    });

    test('TEST 2: Unicode, Emojis, RTL & International Character Integrity', () async {
      const specialNames = [
        '📸_vacation_2026_✨.jpg',
        'отпуск_2026_видео.mp4',
        '假期照片_2026.png',
        'صورة_شخصية.jpeg',
        'file with   spaces & "quotes" (1).jpg',
      ];

      for (final name in specialNames) {
        final testFile = File('${tempDir.path}/$name');
        await testFile.writeAsString('dummy content for $name');
        expect(await testFile.exists(), isTrue);

        final hash = await FileUtils.getFileHash(testFile);
        expect(hash, isNotNull, reason: 'Hash calculation must succeed for non-ASCII names');
      }
    });

    test('TEST 3: Disguised Malicious Payloads (ELF, PE, Mach-O, WASM, Shebang, Java, ZIP)', () async {
      // 1. Linux/Android ELF executable disguised as .jpg
      final elfFile = File('${tempDir.path}/trojan_binary.jpg');
      await elfFile.writeAsBytes([0x7F, 0x45, 0x4C, 0x46, 0x02, 0x01, 0x01, 0x00]);
      final elfResult = await FileSecurityGuard.validateFile(elfFile);
      expect(elfResult.isValid, isFalse);
      expect(elfResult.isMalicious, isTrue);
      expect(elfResult.error, contains('ELF binary'));

      // 2. Windows DOS/PE executable (.exe) disguised as .png
      final peFile = File('${tempDir.path}/ransomware.png');
      await peFile.writeAsBytes([0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00]);
      final peResult = await FileSecurityGuard.validateFile(peFile);
      expect(peResult.isValid, isFalse);
      expect(peResult.isMalicious, isTrue);
      expect(peResult.error, contains('MZ'));

      // 3. Apple Mach-O 64-bit binary disguised as .mp4
      final machOFile = File('${tempDir.path}/mach_binary.mp4');
      await machOFile.writeAsBytes([0xFE, 0xED, 0xFA, 0xCF, 0x00, 0x00, 0x00, 0x01]);
      final machOResult = await FileSecurityGuard.validateFile(machOFile);
      expect(machOResult.isValid, isFalse);
      expect(machOResult.isMalicious, isTrue);
      expect(machOResult.error, contains('Mach-O'));

      // 4. WebAssembly compiled binary (\0asm) disguised as .jpg
      final wasmFile = File('${tempDir.path}/cryptominer.jpg');
      await wasmFile.writeAsBytes([0x00, 0x61, 0x73, 0x6D, 0x01, 0x00, 0x00, 0x00]);
      final wasmResult = await FileSecurityGuard.validateFile(wasmFile);
      expect(wasmResult.isValid, isFalse);
      expect(wasmResult.isMalicious, isTrue);
      expect(wasmResult.error, contains('WebAssembly'));

      // 5. Unix Shebang Bash script disguised as .mp4
      final scriptFile = File('${tempDir.path}/exploit.mp4');
      await scriptFile.writeAsString('#!/bin/bash\nrm -rf /');
      final scriptResult = await FileSecurityGuard.validateFile(scriptFile);
      expect(scriptResult.isValid, isFalse);
      expect(scriptResult.isMalicious, isTrue);
      expect(scriptResult.error, contains('Shebang'));

      // 6. Java bytecode / Mach-O universal disguised as .jpg
      final javaBytecodeFile = File('${tempDir.path}/malware.jpg');
      await javaBytecodeFile.writeAsBytes([0xCA, 0xFE, 0xBA, 0xBE, 0x00, 0x00, 0x00, 0x34]);
      final javaResult = await FileSecurityGuard.validateFile(javaBytecodeFile);
      expect(javaResult.isValid, isFalse);
      expect(javaResult.isMalicious, isTrue);
      expect(javaResult.error, contains('Java class'));

      // 7. Disguised ZIP archive disguised as .png
      final zipFile = File('${tempDir.path}/zipbomb.png');
      await zipFile.writeAsBytes([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00]);
      final zipResult = await FileSecurityGuard.validateFile(zipFile);
      expect(zipResult.isValid, isFalse);
      expect(zipResult.isMalicious, isTrue);
      expect(zipResult.error, contains('ZIP'));
    });

    test('TEST 4: EICAR Standard Antivirus Test Virus String Quarantine', () async {
      const eicarString = r'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*';
      final eicarFile = File('${tempDir.path}/infected_camera_photo.jpg');
      await eicarFile.writeAsString(eicarString);
      final eicarResult = await FileSecurityGuard.validateFile(eicarFile);
      expect(eicarResult.isValid, isFalse);
      expect(eicarResult.isMalicious, isTrue);
      expect(eicarResult.error, contains('EICAR'));
    });

    test('TEST 5: Valid Media Magic Bytes Authentication (JPEG, PNG, GIF, WebP, MP4, MKV)', () async {
      // 1. Valid JPEG (FF D8 FF)
      final validJpg = File('${tempDir.path}/valid_photo.jpg');
      await validJpg.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00]);
      final jpgRes = await FileSecurityGuard.validateFile(validJpg);
      expect(jpgRes.isValid, isTrue);
      expect(jpgRes.detectedType, equals('image/jpeg'));

      // 2. Valid PNG (89 50 4E 47 0D 0A 1A 0A)
      final validPng = File('${tempDir.path}/valid_image.png');
      await validPng.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00]);
      final pngRes = await FileSecurityGuard.validateFile(validPng);
      expect(pngRes.isValid, isTrue);
      expect(pngRes.detectedType, equals('image/png'));

      // 3. Valid GIF89a (GIF89a)
      final validGif = File('${tempDir.path}/valid_anim.gif');
      await validGif.writeAsBytes([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x0A, 0x00, 0x0A, 0x00]);
      final gifRes = await FileSecurityGuard.validateFile(validGif);
      expect(gifRes.isValid, isTrue);
      expect(gifRes.detectedType, equals('image/gif'));

      // 4. Valid WebP (RIFF .... WEBP)
      final validWebp = File('${tempDir.path}/valid_photo.webp');
      await validWebp.writeAsBytes([0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50]);
      final webpRes = await FileSecurityGuard.validateFile(validWebp);
      expect(webpRes.isValid, isTrue);
      expect(webpRes.detectedType, equals('image/webp'));

      // 5. Valid MP4 (ftyp at offset 4)
      final validMp4 = File('${tempDir.path}/valid_video.mp4');
      await validMp4.writeAsBytes([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34, 0x32]);
      final mp4Res = await FileSecurityGuard.validateFile(validMp4);
      expect(mp4Res.isValid, isTrue);
      expect(mp4Res.detectedType, equals('video/mp4'));

      // 6. Valid MKV (1A 45 DF A3)
      final validMkv = File('${tempDir.path}/valid_movie.mkv');
      await validMkv.writeAsBytes([0x1A, 0x45, 0xDF, 0xA3, 0x9F, 0x42, 0x86, 0x81]);
      final mkvRes = await FileSecurityGuard.validateFile(validMkv);
      expect(mkvRes.isValid, isTrue);
      expect(mkvRes.detectedType, equals('video/x-matroska'));
    });

    test('TEST 6: Truncated & Partial Media Headers (Corrupted bytes attack)', () async {
      // 0-byte file
      final zeroByteFile = File('${tempDir.path}/empty.jpg');
      await zeroByteFile.writeAsBytes([]);
      final zeroRes = await FileSecurityGuard.validateFile(zeroByteFile);
      expect(zeroRes.isValid, isFalse);
      expect(zeroRes.error, contains('Empty file'));

      // Truncated JPEG (only 2 bytes)
      final truncJpg = File('${tempDir.path}/partial.jpg');
      await truncJpg.writeAsBytes([0xFF, 0xD8]);
      final truncRes = await FileSecurityGuard.validateFile(truncJpg);
      expect(truncRes.isValid, isFalse);
      expect(truncRes.isMalicious, isTrue);
      expect(truncRes.error, contains('Header mismatch'));

      // Truncated MP4 (only 3 bytes)
      final truncMp4 = File('${tempDir.path}/partial.mp4');
      await truncMp4.writeAsBytes([0x00, 0x00, 0x00]);
      final truncMp4Res = await FileSecurityGuard.validateFile(truncMp4);
      expect(truncMp4Res.isValid, isFalse);
      expect(truncMp4Res.isMalicious, isTrue);
      expect(truncMp4Res.error, contains('Header mismatch'));
    });

    test('TEST 7: Telegram MarkdownV2 Entity Injection & Link Defense', () {
      const injectionStrings = [
        '*bold_syntax_error.jpg',
        '_italic_unclosed.png',
        '[Phishing Link](https://attacker.com/malware.apk)',
        '`code_injection_test.mp4`',
        'file~tilde.jpg',
        'photo#1>trending|special.jpg',
        r'path\with\backslashes.jpg',
      ];

      for (final raw in injectionStrings) {
        final escaped = FileSecurityGuard.escapeTelegramMarkdown(raw);
        if (raw.contains('*')) expect(escaped.contains(r'\*'), isTrue);
        if (raw.contains('_')) expect(escaped.contains(r'\_'), isTrue);
        if (raw.contains('[')) expect(escaped.contains(r'\['), isTrue);
        if (raw.contains(']')) expect(escaped.contains(r'\]'), isTrue);
        if (raw.contains('`')) expect(escaped.contains(r'\`'), isTrue);
        if (raw.contains('~')) expect(escaped.contains(r'\~'), isTrue);
        if (raw.contains('>')) expect(escaped.contains(r'\>'), isTrue);
        if (raw.contains('#')) expect(escaped.contains(r'\#'), isTrue);
        if (raw.contains('|')) expect(escaped.contains(r'\|'), isTrue);
      }
    });

    test('TEST 8: SSRF Attack Vectors & Cloud Metadata Protection', () {
      final testCases = <String, bool>{
        'http://169.254.169.254/latest/meta-data/': false, // AWS metadata SSRF -> REJECTED
        'http://metadata.google.internal/computeMetadata/v1/': false, // GCP metadata SSRF -> REJECTED
        'file:///etc/passwd': false,                        // Local file access -> REJECTED
        'javascript:alert(1)': false,                       // XSS scheme -> REJECTED
        'ftp://anonymous:pass@evil.com/': false,            // Non-HTTP protocol -> REJECTED
        'http://api.telegram.org': false,                   // Plain HTTP to remote -> REJECTED (Needs HTTPS)
        'https://api.telegram.org': true,                   // Official Telegram HTTPS -> ALLOWED
        'https://my-telegram-bot-api.internal.org': true,   // Custom HTTPS domain -> ALLOWED
        'http://localhost:8081': true,                      // Localhost HTTP dev -> ALLOWED
        'http://127.0.0.1:8081': true,                      // Local loopback HTTP dev -> ALLOWED
      };

      testCases.forEach((url, expectedValid) {
        final result = FileSecurityGuard.validateApiUrl(url);
        expect(
          result.isValid,
          expectedValid,
          reason: 'URL $url expected isValid=$expectedValid, but got ${result.isValid} (${result.error})',
        );
      });
    });

    test('TEST 9: Massive Queue Stress & Chronological Monotonic Sorting (2,000 files)', () {
      final items = <MediaItem>[];
      final now = DateTime.now().millisecondsSinceEpoch;

      // Scramble 2,000 items with non-linear pseudo-random timestamps
      for (int i = 0; i < 2000; i++) {
        final randomOffset = (i * 982451) % 800000000;
        final timestamp = now - randomOffset;
        items.add(MediaItem(
          filePath: '/storage/emulated/0/DCIM/Camera/IMG_$i.jpg',
          mimeType: 'image/jpeg',
          dateTaken: timestamp,
          fileSize: 1024 * 1024,
          status: MediaItem.statusPending,
          updatedAt: now,
        ));
      }

      // Sort chronological (oldest to newest)
      items.sort((a, b) => a.dateTaken.compareTo(b.dateTaken));

      // Assert strictly monotonic chronological ordering across all 2,000 items
      for (int i = 0; i < items.length - 1; i++) {
        expect(items[i].dateTaken <= items[i + 1].dateTaken, isTrue,
            reason: 'Item $i must be older or equal to Item ${i + 1}');
      }
    });

    test('TEST 10: Credential Masking & Information Leakage Prevention', () {
      const realToken = '7123456789:AAFlkjhsdf89234jsdf_fakeToken99';
      final masked = FileSecurityGuard.maskToken(realToken);
      expect(masked.contains('AAFlkjhsdf89234jsdf_fakeToken99'), isFalse, reason: 'Full token must not be exposed');
      expect(masked, equals('7123456789:AAF...n99'));

      // Empty token test
      expect(FileSecurityGuard.maskToken(''), equals('Not configured'));
    });

    test('TEST 11: Deduplication & SHA-256 Checksum Integrity', () async {
      final fileA = File('${tempDir.path}/original.jpg');
      final fileB = File('${tempDir.path}/copy.jpg');
      final fileC = File('${tempDir.path}/different.jpg');

      const bytesA = [0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02, 0x03, 0x04];
      const bytesC = [0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02, 0x03, 0x05]; // Differs by 1 bit

      await fileA.writeAsBytes(bytesA);
      await fileB.writeAsBytes(bytesA);
      await fileC.writeAsBytes(bytesC);

      final hashA = await FileUtils.getFileHash(fileA);
      final hashB = await FileUtils.getFileHash(fileB);
      final hashC = await FileUtils.getFileHash(fileC);

      expect(hashA, isNotNull);
      expect(hashA, equals(hashB), reason: 'Identical bytes must produce identical hashes');
      expect(hashA, isNot(equals(hashC)), reason: 'Distinct bytes must produce distinct hashes');
    });

    test('TEST 12: In-Memory Multi-Part Slicing Math Verification', () {
      const chunkSize = 48 * 1024 * 1024; // 48 MB
      const totalBytes = 145 * 1024 * 1024; // 145 MB file

      final totalParts = (totalBytes / chunkSize).ceil();
      expect(totalParts, equals(4)); // 48 + 48 + 48 + 1 = 145 MB

      int accumulated = 0;
      for (int part = 1; part <= totalParts; part++) {
        final bytesToRead = (part == totalParts) ? (totalBytes - (part - 1) * chunkSize) : chunkSize;
        accumulated += bytesToRead;
        if (part < totalParts) {
          expect(bytesToRead, equals(chunkSize));
        } else {
          expect(bytesToRead, equals(1 * 1024 * 1024)); // Remaining 1 MB
        }
      }

      expect(accumulated, equals(totalBytes), reason: 'All chunk slices must sum exactly to total file size');
    });
  });
}
