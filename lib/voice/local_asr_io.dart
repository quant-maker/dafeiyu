// On-device ASR: Dolphin (2025) by default, SenseVoice as the alternative.
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class LocalAsrImpl {
  LocalAsrImpl._(this._dir, this.kind);

  final Directory _dir;
  final String kind; // 'dolphin' | 'sensevoice'
  sherpa.OfflineRecognizer? _recognizer;

  static const models = <String, String>{
    'dolphin': 'Dolphin 2025（99 MB，快）',
    'sensevoice': 'SenseVoice（228 MB，方言更强）',
  };

  static const _urls = <String, String>{
    'dolphin':
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-dolphin-base-ctc-multi-lang-int8-2025-04-02.tar.bz2',
    'sensevoice':
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17.tar.bz2',
  };

  static Future<LocalAsrImpl> create({String kind = 'dolphin'}) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/asr_$kind');
    if (!await dir.exists()) await dir.create(recursive: true);
    return LocalAsrImpl._(dir, kind);
  }

  File get _model => File('${_dir.path}/model.int8.onnx');
  File get _tokens => File('${_dir.path}/tokens.txt');

  Future<bool> get ready async => await _model.exists() && await _tokens.exists();

  Future<void> download({void Function(double progress)? onProgress}) async {
    final url = _urls[kind]!;
    final tmp = File('${_dir.path}/bundle.tar.bz2');
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(url)));
      if (res.statusCode != 200) throw Exception('下载失败 HTTP ${res.statusCode}');
      final total = res.contentLength ?? 0;
      var got = 0;
      final sink = tmp.openWrite();
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) onProgress?.call(got / total * 0.85);
        }
      } finally {
        await sink.close();
      }

      onProgress?.call(0.86);
      final bytes = await tmp.readAsBytes();
      final tar = BZip2Decoder().decodeBytes(bytes);
      final entries = TarDecoder().decodeBytes(tar);
      for (final entry in entries) {
        if (!entry.isFile) continue;
        final parts = entry.name.split('/');
        final name = parts.last;
        // Only the pieces the recogniser needs.
        if (name != 'model.int8.onnx' && name != 'tokens.txt') continue;
        await File('${_dir.path}/$name').writeAsBytes(entry.content as List<int>);
      }
      await tmp.delete();
      onProgress?.call(1);
    } finally {
      client.close();
    }
  }

  sherpa.OfflineRecognizer _engine() {
    final cached = _recognizer;
    if (cached != null) return cached;

    sherpa.initBindings();
    final model = kind == 'dolphin'
        ? sherpa.OfflineModelConfig(
            dolphin: sherpa.OfflineDolphinModelConfig(model: _model.path),
            tokens: _tokens.path,
            numThreads: 2,
            debug: false,
          )
        : sherpa.OfflineModelConfig(
            senseVoice: sherpa.OfflineSenseVoiceModelConfig(
              model: _model.path,
              language: 'zh',
              useInverseTextNormalization: true,
            ),
            tokens: _tokens.path,
            numThreads: 2,
            debug: false,
          );

    final engine = sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(model: model));
    _recognizer = engine;
    return engine;
  }

  /// Accepts a 16 kHz mono PCM16 WAV file.
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
