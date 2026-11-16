/// Android / desktop: sherpa-onnx runs the SenseVoice model fully on device.
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class LocalAsrImpl {
  LocalAsrImpl._(this._dir);

  final Directory _dir;
  sherpa.OfflineRecognizer? _recognizer;

  static const _modelUrl =
      'https://hf-mirror.com/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx';
  static const _tokensUrl =
      'https://hf-mirror.com/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/tokens.txt';

  static Future<LocalAsrImpl> create() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/sensevoice');
    if (!await dir.exists()) await dir.create(recursive: true);
    return LocalAsrImpl._(dir);
  }

  File get _model => File('${_dir.path}/model.int8.onnx');
  File get _tokens => File('${_dir.path}/tokens.txt');

  Future<bool> get ready async => await _model.exists() && await _tokens.exists();

  Future<void> download({void Function(double progress)? onProgress}) async {
    await _fetch(_modelUrl, _model, (p) => onProgress?.call(p * 0.98));
    await _fetch(_tokensUrl, _tokens, (p) => onProgress?.call(0.98 + p * 0.02));
    onProgress?.call(1);
  }

  Future<void> _fetch(String url, File dest, void Function(double) onProgress) async {
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(url)));
      if (res.statusCode != 200) {
        throw Exception('下载失败 HTTP ${res.statusCode}');
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = dest.openWrite();
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress(received / total);
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  sherpa.OfflineRecognizer _engine() {
    final cached = _recognizer;
    if (cached != null) return cached;

    sherpa.initBindings();
    final config = sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        senseVoice: sherpa.OfflineSenseVoiceModelConfig(
          model: _model.path,
          language: 'zh',
          useInverseTextNormalization: true,
        ),
        tokens: _tokens.path,
        numThreads: 2,
        debug: false,
      ),
    );
    final engine = sherpa.OfflineRecognizer(config);
    _recognizer = engine;
    return engine;
  }

  /// Accepts a 16 kHz mono PCM16 WAV file (what `record` writes).
  Future<String?> transcribe(String wavPath) async {
    if (!await ready) return null;
    final samples = await _readWav(wavPath);
    if (samples == null || samples.isEmpty) return null;

    final engine = _engine();
    final stream = engine.createStream();
    stream.acceptWaveform(samples: samples, sampleRate: 16000);
    engine.decode(stream);
    final text = engine.getResult(stream).text.trim();
    return text.isEmpty ? null : text;
  }

  static Future<Float32List?> _readWav(String path) async {
    final bytes = await File(path).readAsBytes();
    if (bytes.length < 44) return null;
    // Find the "data" chunk instead of assuming a 44-byte header.
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = ByteData.sublistView(bytes, offset + 4, offset + 8).getUint32(0, Endian.little);
      if (id == 'data') {
        final start = offset + 8;
        final end = (start + size).clamp(0, bytes.length);
        final pcm = ByteData.sublistView(bytes, start, end);
        final count = (end - start) ~/ 2;
        final out = Float32List(count);
        for (var i = 0; i < count; i++) {
          out[i] = pcm.getInt16(i * 2, Endian.little) / 32768.0;
        }
        return out;
      }
      offset += 8 + size + (size.isOdd ? 1 : 0);
    }
    return null;
  }
}
