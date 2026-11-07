import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtsky_flutter/services/crypto/optimized_aes_ige.dart';

void main() {
  group('OptimizedAesIge Tests', () {
    test('Encrypts and decrypts with round-trip fidelity', () {
      final engine = OptimizedAesIge();

      // 256-bit key (32 bytes)
      final key = Uint8List.fromList(List.generate(32, (i) => i * 7 % 256));
      // 32-byte IV for IGE mode
      final iv = Uint8List.fromList(List.generate(32, (i) => (i * 13 + 5) % 256));

      // 64-byte plaintext (multiple of 16)
      final plaintext = Uint8List.fromList(List.generate(64, (i) => i % 256));

      // Encrypt
      engine.init(key: key, encrypt: true);
      final ciphertext = engine.process(input: plaintext, iv: iv, encrypt: true);

      expect(ciphertext.length, equals(plaintext.length));
      expect(ciphertext, isNot(equals(plaintext)));

      // Decrypt
      engine.init(key: key, encrypt: false);
      final decrypted = engine.process(input: ciphertext, iv: iv, encrypt: false);

      expect(decrypted, equals(plaintext));
    });

    test('Works on large multi-block (512 KB) chunk buffer without allocation stalls', () {
      final engine = OptimizedAesIge();
      final key = Uint8List(32)..fillRange(0, 32, 0x42);
      final iv = Uint8List(32)..fillRange(0, 32, 0x24);

      final chunkSize = 512 * 1024;
      final largeBuffer = Uint8List(chunkSize);
      for (int i = 0; i < chunkSize; i++) {
        largeBuffer[i] = i & 0xFF;
      }

      engine.init(key: key, encrypt: true);
      final ciphertext = engine.process(input: largeBuffer, iv: iv, encrypt: true);
      expect(ciphertext.length, equals(chunkSize));

      engine.init(key: key, encrypt: false);
      final decrypted = engine.process(input: ciphertext, iv: iv, encrypt: false);
      expect(decrypted, equals(largeBuffer));
    });

    test('Safely performs in-place encryption and decryption without buffer corruption', () {
      final engine = OptimizedAesIge();
      final key = Uint8List.fromList(List.generate(32, (i) => (i * 3 + 17) % 256));
      final iv = Uint8List.fromList(List.generate(32, (i) => (i * 11 + 3) % 256));

      final originalData = Uint8List.fromList(List.generate(256, (i) => (i * 5) % 256));
      final inPlaceBuffer = Uint8List.fromList(originalData);

      // In-place encryption: outputBuffer == input
      engine.init(key: key, encrypt: true);
      engine.process(input: inPlaceBuffer, iv: iv, encrypt: true, outputBuffer: inPlaceBuffer);
      expect(inPlaceBuffer, isNot(equals(originalData)));

      // In-place decryption: outputBuffer == input
      engine.init(key: key, encrypt: false);
      engine.process(input: inPlaceBuffer, iv: iv, encrypt: false, outputBuffer: inPlaceBuffer);
      expect(inPlaceBuffer, equals(originalData));
    });

    test('Handles unaligned byte views gracefully without alignment errors', () {
      final engine = OptimizedAesIge();
      final key = Uint8List(32)..fillRange(0, 32, 0x55);
      final iv = Uint8List(32)..fillRange(0, 32, 0xAA);

      // Create a backing buffer with unaligned offset (e.g. offset 3)
      final raw = Uint8List(128);
      for (int i = 0; i < raw.length; i++) {
        raw[i] = i & 0xFF;
      }
      // Subview of length 32 starting at offset 3 (unaligned by 8)
      final unalignedInput = Uint8List.sublistView(raw, 3, 3 + 32);

      engine.init(key: key, encrypt: true);
      final encrypted = engine.process(input: unalignedInput, iv: iv, encrypt: true);
      expect(encrypted.length, equals(32));

      engine.init(key: key, encrypt: false);
      final decrypted = engine.process(input: encrypted, iv: iv, encrypt: false);
      expect(decrypted, equals(unalignedInput));
    });
  });
}
