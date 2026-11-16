import 'dart:io';

/// Offline speech recognition (sherpa-onnx + SenseVoice). Returns null on
/// platforms where it is not available (web).
abstract class LocalAsr {
  static Future<LocalAsr> instance() async => throw UnsupportedError('no local asr');

  Future<bool> get ready;
  Future<void> download({void Function(double progress)? onProgress});
  Future<String?> transcribe(String wavPath);
}

/// Shared file layout, used by both implementations.
class LocalAsrFiles {
  static const modelFile = 'model.int8.onnx';
  static const tokensFile = 'tokens.txt';
  static const modelUrl =
      'https://hf-mirror.com/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx';
  static const tokensUrl =
      'https://hf-mirror.com/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/tokens.txt';

  static Future<Directory> dir() async {
    final base = Directory('${Platform.environment['HOME'] ?? '.'}');
    return base;
  }
}
