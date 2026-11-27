// On-device speech synthesis with Kokoro (via sherpa-onnx).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class LocalTtsImpl {
  LocalTtsImpl._(this._dir);

  final Directory _dir;
  final AudioPlayer _player = AudioPlayer();
  sherpa.OfflineTts? _engine;

  static const _bundleUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-multi-lang-v1_1.tar.bz2';

  /// GitHub 在国内经常解析不了，hf-mirror 有同一个模型仓库的文件树。
  static const _repo = 'csukuangfj/kokoro-int8-multi-lang-v1_1';
  static const _fileBase = 'https://hf-mirror.com/$_repo/resolve/main';

  static const _wanted = <String>{
    'model.int8.onnx',
    'voices.bin',
    'tokens.txt',
    'lexicon-us-en.txt',
    'lexicon-zh.txt',
    'date-zh.fst',
    'number-zh.fst',
    'phone-zh.fst',
  };

  static Future<LocalTtsImpl> create() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/kokoro');
    if (!await dir.exists()) await dir.create(recursive: true);
    return LocalTtsImpl._(dir);
  }

  /// Chinese voices shipped with the multi-lang bundle.
  static const voices = <int, String>{
    45: '小贝（女）',
    46: '小妮（女）',
    47: '小小（女）',
    48: '小艺（女）',
    49: '云间（男）',
    50: '云希（男）',
    51: '云夏（男）',
    52: '云扬（男）',
  };

  File get _model => File('${_dir.path}/model.onnx');

  Future<bool> get ready async => await _model.exists();

  /// Mirror first (works in China), GitHub bundle as the fallback.
  Future<void> download({void Function(double progress)? onProgress}) async {
    try {
      await _downloadFromMirror(onProgress);
      return;
    } catch (e) {
      debugPrint('[feiyu] kokoro mirror download failed, trying github: $e');
    }
    await _downloadBundle(onProgress);
  }

  /// The mirror exposes the unpacked bundle; pull the files the engine needs.
  Future<void> _downloadFromMirror(void Function(double progress)? onProgress) async {
    final client = http.Client();
    try {
      final res = await client
          .get(Uri.parse('https://hf-mirror.com/api/models/$_repo?blobs=true'))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw Exception('列表接口 HTTP ${res.statusCode}');
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final siblings = (json['siblings'] as List? ?? const []).cast<Map<String, dynamic>>();

      final files = <MapEntry<String, int>>[];
      for (final f in siblings) {
        final name = (f['rfilename'] ?? '').toString();
        if (!_wanted.contains(name) &&
            !name.startsWith('espeak-ng-data/') &&
            !name.startsWith('dict/')) {
          continue;
        }
        if (name.endsWith('.md') || name.endsWith('.py')) continue;
        files.add(MapEntry(name, (f['size'] as num?)?.toInt() ?? 0));
      }
      if (files.isEmpty) throw Exception('下载列表为空');

      final total = files.fold<int>(0, (sum, e) => sum + e.value);
      var done = 0;
      for (final f in files) {
        final target = File('${_dir.path}/${f.key == 'model.int8.onnx' ? 'model.onnx' : f.key}');
        await target.parent.create(recursive: true);
        final res = await client.send(http.Request('GET', Uri.parse('$_fileBase/${f.key}')));
        if (res.statusCode != 200) throw Exception('下载 ${f.key} 失败 HTTP ${res.statusCode}');
        final sink = target.openWrite();
        try {
          await for (final chunk in res.stream) {
            sink.add(chunk);
            done += chunk.length;
            if (total > 0) onProgress?.call(done / total * 0.99);
          }
        } finally {
          await sink.close();
        }
      }
      onProgress?.call(1);
    } finally {
      client.close();
    }
  }

  Future<void> _downloadBundle(void Function(double progress)? onProgress) async {
    final archiveFile = File('${_dir.path}/kokoro.tar.bz2');
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(_bundleUrl)));
      if (res.statusCode != 200) throw Exception('下载失败 HTTP ${res.statusCode}');
      final total = res.contentLength ?? 0;
      var got = 0;
      final sink = archiveFile.openWrite();
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          got += chunk.length;
          // Download is ~85% of the work; extraction is the rest.
          if (total > 0) onProgress?.call(got / total * 0.85);
        }
      } finally {
        await sink.close();
      }

      onProgress?.call(0.86);
      final bytes = await archiveFile.readAsBytes();
      final tar = BZip2Decoder().decodeBytes(bytes);
      final entries = TarDecoder().decodeBytes(tar);
      // Files live under a top-level folder; strip it.
      for (final entry in entries) {
        if (entry.isFile) {
          final parts = entry.name.split('/');
          final rel = parts.length > 1 ? parts.sublist(1).join('/') : entry.name;
          // The mirror path stores the quantised name; the engine wants model.onnx.
          final out = File('${_dir.path}/${rel == 'model.int8.onnx' ? 'model.onnx' : rel}');
          await out.parent.create(recursive: true);
          await out.writeAsBytes(entry.content as List<int>);
        }
      }
      await archiveFile.delete();
      onProgress?.call(1);
    } finally {
      client.close();
    }
  }

  sherpa.OfflineTts _tts() {
    final cached = _engine;
    if (cached != null) return cached;

    sherpa.initBindings();
    final config = sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        kokoro: sherpa.OfflineTtsKokoroModelConfig(
          model: '${_dir.path}/model.onnx',
          voices: '${_dir.path}/voices.bin',
          tokens: '${_dir.path}/tokens.txt',
          dataDir: '${_dir.path}/espeak-ng-data',
          dictDir: '${_dir.path}/dict',
          lexicon: '${_dir.path}/lexicon-us-en.txt,${_dir.path}/lexicon-zh.txt',
          lang: 'zh',
        ),
        numThreads: 2,
        debug: false,
      ),
    );
    final engine = sherpa.OfflineTts(config);
    _engine = engine;
    return engine;
  }

  Future<bool> speak(
    String text, {
    int sid = 47,
    double speed = 1.0,
    bool awaitCompletion = false,
  }) async {
    if (!await ready) return false;
    final clean = text.replaceAll(RegExp(r'[*#`>_\[\]()]'), ' ').trim();
    if (clean.isEmpty) return false;

    try {
      final audio = _tts().generate(text: clean, sid: sid, speed: speed);
      if (audio.samples.isEmpty) return false;
      final path = '${_dir.path}/out_${DateTime.now().microsecondsSinceEpoch}.wav';
      await _writeWav(path, audio.samples, audio.sampleRate);
      await _player.stop();
      // Subscribe before play so a very short clip cannot complete first.
      Future<void>? finished;
      if (awaitCompletion) {
        finished = _player.onPlayerComplete.first
            .timeout(const Duration(seconds: 60))
            .then<void>((_) {}, onError: (Object _) {});
      }
      await _player.play(DeviceFileSource(path));
      await finished;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  static Future<void> _writeWav(String path, Float32List samples, int rate) async {
    final pcm = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i] * 32767).clamp(-32768, 32767).toInt();
      pcm[i] = v;
    }
    final data = pcm.buffer.asUint8List();
    final b = BytesBuilder();
    void str(String s) => b.add(s.codeUnits);
    void u32(int v) => b.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
    void u16(int v) => b.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

    str('RIFF');
    u32(36 + data.length);
    str('WAVEfmt ');
    u32(16);
    u16(1);
    u16(1);
    u32(rate);
    u32(rate * 2);
    u16(2);
    u16(16);
    str('data');
    u32(data.length);
    b.add(data);

    await File(path).writeAsBytes(b.toBytes());
  }
}
