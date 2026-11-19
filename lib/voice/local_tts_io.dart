// On-device speech synthesis with Kokoro (via sherpa-onnx).
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
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

  Future<void> download({void Function(double progress)? onProgress}) async {
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
          final out = File('${_dir.path}/$rel');
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

  Future<bool> speak(String text, {int sid = 47, double speed = 1.0}) async {
    if (!await ready) return false;
    final clean = text.replaceAll(RegExp(r'[*#`>_\[\]()]'), ' ').trim();
    if (clean.isEmpty) return false;

    try {
      final audio = _tts().generate(text: clean, sid: sid, speed: speed);
      if (audio.samples.isEmpty) return false;
      final path = '${_dir.path}/out_${DateTime.now().microsecondsSinceEpoch}.wav';
      await _writeWav(path, audio.samples, audio.sampleRate);
      await _player.stop();
      await _player.play(DeviceFileSource(path));
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
