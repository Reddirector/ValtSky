import 'dart:typed_data';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';

/// High-performance PointyCastle-based AES-256-IGE execution engine.
/// Reuses pre-allocated scratch buffers, initialized key schedules, and 64-bit register XORs
/// to eliminate thousands of object allocations per chunk during MTProto uploads.
class OptimizedAesIge {
  final AESEngine _engine = AESEngine();
  Uint8List? _currentKey;
  bool? _currentDirection;

  /// Initializes the cipher key schedule once per key and direction.
  void init({required Uint8List key, required bool encrypt}) {
    if (_currentKey == null ||
        _currentDirection != encrypt ||
        !_areBuffersEqual(_currentKey!, key)) {
      _currentKey = Uint8List.fromList(key);
      _currentDirection = encrypt;
      _engine.reset();
      _engine.init(encrypt, KeyParameter(key));
    }
  }

  /// Processes [input] using AES-IGE mode with 64-bit word XORs and in-place block transformation.
  /// [input.length] must be a multiple of 16 bytes.
  Uint8List process({
    required Uint8List input,
    required Uint8List iv,
    required bool encrypt,
    Uint8List? outputBuffer,
  }) {
    assert(input.length % 16 == 0, 'AES_IGE input size must be divisible by 16.');
    assert(iv.length == 32, 'AES_IGE IV must be exactly 32 bytes.');
    assert(_currentDirection == encrypt, 'init() direction must match process() direction');

    // Ensure byte offset alignment for 64-bit word access
    final Uint8List alignedInput = (input.offsetInBytes % 8 == 0)
        ? input
        : Uint8List.fromList(input);

    final bool canUseOutputDirectly = outputBuffer != null &&
        outputBuffer.length >= input.length &&
        outputBuffer.offsetInBytes % 8 == 0;

    final Uint8List output = canUseOutputDirectly
        ? outputBuffer
        : Uint8List(input.length);

    final prevBytes = Uint8List.fromList(iv);
    final span = alignedInput.buffer.asInt64List(alignedInput.offsetInBytes, alignedInput.lengthInBytes ~/ 8);
    final sout = output.buffer.asInt64List(output.offsetInBytes, alignedInput.lengthInBytes ~/ 8);
    final prev = prevBytes.buffer.asInt64List(prevBytes.offsetInBytes, 4);

    if (!encrypt) {
      final t0 = prev[2];
      prev[2] = prev[0];
      prev[0] = t0;

      final t1 = prev[3];
      prev[3] = prev[1];
      prev[1] = t1;
    }

    final int count = input.length ~/ 8;
    for (int i = 0; i < count; i += 2) {
      // Cache input words to prevent corruption in in-place (aliased output) operations
      final in0 = span[i];
      final in1 = span[i + 1];

      sout[i] = in0 ^ prev[0];
      sout[i + 1] = in1 ^ prev[1];

      // Perform 16-byte block cipher in-place
      final byteOffset = i * 8;
      _engine.processBlock(output, byteOffset, output, byteOffset);

      prev[0] = sout[i] ^= prev[2];
      prev[1] = sout[i + 1] ^= prev[3];
      prev[2] = in0;
      prev[3] = in1;
    }

    if (outputBuffer != null && !canUseOutputDirectly) {
      outputBuffer.setRange(0, input.length, output);
      return outputBuffer;
    }

    return output;
  }

  static bool _areBuffersEqual(Uint8List a, Uint8List b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
