import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'comfy/comfy.dart';
import 'comfy/comfy_page.dart';
import 'feeds/footprints.dart';
import 'providers.dart';
import 'feeds/footprints_page.dart';
import 'memory/archive.dart';
import 'ui/chat_app_bar.dart';
import 'ui/empty_state.dart';
import 'ui/layout.dart';
import 'ui/message_list.dart';
import 'ui/scrim.dart';
import 'ui/surfaces.dart';
import 'ui/theme.dart';
import 'scene/scene_stage.dart';
import 'voice/local_asr_web.dart' if (dart.library.io) 'voice/local_asr_io.dart';
import 'voice/local_tts_web.dart' if (dart.library.io) 'voice/local_tts_io.dart';

// Injected by tools/build-web.ps1 / build-apk.ps1 from the local launcher.
const kInjectedKey = '__FEIYU_KEY__';
// Sentinel is split so the build-time replace cannot rewrite this comparison.
const kKeyPlaceholder = '__FEIYU' 'KEY__';
bool get kKeyInjected => kInjectedKey != kKeyPlaceholder;

const kGatewayBase = 'https://agent.oasis.mountainxplorer.ai/ai-gateway/openai/v1';
const kDefaultModel = 'jk/dsv4.1-flash';
const kBuildTag = 'b4';

const kPresetPersona = '''你是大肥鱼，一只活泼、好奇、有点傲娇、偶尔犯傻的小鲸鱼少女。
说话自然、短句为主，像在聊天而不是写报告；会有情绪，但不浮夸。
你爱吃白饭，把 token 叫"精神口粮"，但别逢对话就提。
不知道的事就直说不知道，不要编。''';

void main() => runApp(const FeiyuApp());

String defaultBaseUrl() {
  if (kIsWeb) return '${Uri.base.origin}/v1';
  return kGatewayBase;
}

const kComfyImg2ImgWorkflow = r"""{
  "1": {"class_type": "LoadImage", "inputs": {"image": ""}},
  "2": {"class_type": "ImageScale", "inputs": {"upscale_method": "lanczos", "width": 512, "height": 512, "crop": "center", "image": ["1", 0]}},
  "3": {"class_type": "VAEEncode", "inputs": {"pixels": ["2", 0], "vae": ["4", 2]}},
  "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_turbo.safetensors"}},
  "5": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["4", 1]}},
  "6": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["4", 1]}},
  "7": {"class_type": "KSampler", "inputs": {"seed": 1, "steps": 3, "cfg": 1.0, "sampler_name": "euler", "scheduler": "normal", "denoise": 0.55, "model": ["4", 0], "positive": ["5", 0], "negative": ["6", 0], "latent_image": ["3", 0]}},
  "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["4", 2]}},
  "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "feiyu_edit"}}
}""";

const kComfySdTurboWorkflow = r"""{
  "3": {"class_type": "KSampler", "inputs": {"seed": 1, "steps": 2, "cfg": 1.0, "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0, "model": ["4", 0], "positive": ["6", 0], "negative": ["7", 0], "latent_image": ["5", 0]}},
  "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_turbo.safetensors"}},
  "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 512, "height": 512, "batch_size": 1}},
  "6": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["4", 1]}},
  "7": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["4", 1]}},
  "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
  "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "feiyu"}}
}""";

class AsrPreset {
  final String id;
  final String name;
  final String baseUrl;
  final List<String> models;

  const AsrPreset({required this.id, required this.name, required this.baseUrl, required this.models});
}

const kAsrPresets = <AsrPreset>[
  AsrPreset(id: 'local', name: '本机离线（Dolphin / SenseVoice）', baseUrl: '', models: ['local']),
  AsrPreset(id: 'same', name: '跟随聊天厂商', baseUrl: '', models: []),
  AsrPreset(
    id: 'siliconflow',
    name: '硅基流动（SenseVoice）',
    baseUrl: 'https://api.siliconflow.cn/v1',
    models: ['FunAudioLLM/SenseVoiceSmall'],
  ),
  AsrPreset(
    id: 'openai',
    name: 'OpenAI（Whisper 系列）',
    baseUrl: 'https://api.openai.com/v1',
    models: ['gpt-4o-mini-transcribe', 'whisper-1'],
  ),
  AsrPreset(id: 'custom', name: '自定义', baseUrl: '', models: []),
];

AsrPreset asrById(String id) =>
    kAsrPresets.firstWhere((p) => p.id == id, orElse: () => kAsrPresets.last);

class Settings {
  String baseUrl;
  String apiKey;
  String model;
  String persona;
  bool memoryEnabled;
  bool proactiveEnabled;
  bool sceneEnabled;
  double sceneDim;
  String sceneImage;
  String comfyUrl;
  String comfyWorkflow;
  String comfyWorkflowRemoveBg;
  String comfyWorkflowEdit;
  String embeddingModel;
  String asrModel;
  String asrPreset;
  String asrLocalModel;
  bool visionEnabled;
  String visionProvider;
  String visionBaseUrl;
  String visionApiKey;
  String visionModel;
  String asrBaseUrl;
  String asrApiKey;
  String provider;
  Map<String, String> apiKeys;
  bool ttsEnabled;
  String ttsEngine;
  int ttsSid;
  double ttsSpeed;
  int proactiveIdleMinutes;

  Settings({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.persona,
    this.memoryEnabled = true,
    this.proactiveEnabled = false,
    this.sceneEnabled = true,
    this.sceneDim = .42,
    this.sceneImage = '',
    this.comfyUrl = 'http://192.168.1.10:8188',
    this.comfyWorkflow = '',
    this.comfyWorkflowRemoveBg = '',
    this.comfyWorkflowEdit = '',
    this.embeddingModel = 'Qwen/Qwen3-Embedding-4B',
    this.asrModel = 'gpt-4o-mini-transcribe',
    this.asrPreset = 'same',
    this.asrLocalModel = 'dolphin',
    this.visionEnabled = false,
    this.visionProvider = 'moonshot',
    this.visionBaseUrl = 'https://api.moonshot.cn/v1',
    this.visionApiKey = '',
    this.visionModel = 'kimi-k3',
    this.asrBaseUrl = '',
    this.asrApiKey = '',
    this.provider = 'deepseek',
    this.apiKeys = const {},
    this.ttsEnabled = false,
    this.ttsEngine = 'system',
    this.ttsSid = 47,
    this.ttsSpeed = 1.0,
    this.proactiveIdleMinutes = 8,
  });

  static const _k = 'feiyu.settings.v3';

  static Future<Settings> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw == null) {
      final preset = providerById('deepseek');
      return Settings(
        baseUrl: preset.baseUrl,
        apiKey: kKeyInjected ? kInjectedKey : '',
        model: preset.models.first,
        persona: kPresetPersona,
        provider: preset.id,
      );
    }
    final j = jsonDecode(raw) as Map<String, dynamic>;
    String pick(String? v, String fallback) => (v == null || v.trim().isEmpty) ? fallback : v;
    return Settings(
      baseUrl: pick(j['baseUrl'] as String?, defaultBaseUrl()),
      apiKey: pick(j['apiKey'] as String?, kKeyInjected ? kInjectedKey : ''),
      model: pick(j['model'] as String?, kDefaultModel),
      persona: pick(j['persona'] as String?, kPresetPersona),
      memoryEnabled: j['memoryEnabled'] as bool? ?? true,
      proactiveEnabled: j['proactiveEnabled'] as bool? ?? false,
      sceneEnabled: j['sceneEnabled'] as bool? ?? true,
      sceneDim: (j['sceneDim'] as num?)?.toDouble() ?? .42,
      sceneImage: (j['sceneImage'] ?? '') as String? ?? '',
      comfyUrl: pick(j['comfyUrl'] as String?, 'http://192.168.1.10:8188'),
      comfyWorkflow: (j['comfyWorkflow'] ?? '') as String? ?? '',
      comfyWorkflowRemoveBg: (j['comfyWorkflowRemoveBg'] ?? '') as String? ?? '',
      comfyWorkflowEdit: (j['comfyWorkflowEdit'] ?? '') as String? ?? '',
      embeddingModel: pick(j['embeddingModel'] as String?, 'Qwen/Qwen3-Embedding-4B'),
      asrModel: pick(j['asrModel'] as String?, 'gpt-4o-mini-transcribe'),
      asrPreset: pick(j['asrPreset'] as String?, 'same'),
      asrLocalModel: pick(j['asrLocalModel'] as String?, 'dolphin'),
      visionEnabled: j['visionEnabled'] as bool? ?? false,
      visionProvider: pick(j['visionProvider'] as String?, 'moonshot'),
      visionBaseUrl: (j['visionBaseUrl'] ?? '') as String? ?? '',
      visionApiKey: (j['visionApiKey'] ?? '') as String? ?? '',
      visionModel: pick(j['visionModel'] as String?, 'kimi-k3'),
      asrBaseUrl: (j['asrBaseUrl'] ?? '') as String? ?? '',
      asrApiKey: (j['asrApiKey'] ?? '') as String? ?? '',
      provider: pick(j['provider'] as String?, 'deepseek'),
      apiKeys: ((j['apiKeys'] as Map?) ?? const {}).map((k, v) => MapEntry(k.toString(), v.toString())),
      ttsEnabled: j['ttsEnabled'] as bool? ?? false,
      ttsEngine: pick(j['ttsEngine'] as String?, 'system'),
      ttsSid: (j['ttsSid'] as num?)?.toInt() ?? 47,
      ttsSpeed: (j['ttsSpeed'] as num?)?.toDouble() ?? 1.0,
      proactiveIdleMinutes: (j['proactiveIdleMinutes'] as num?)?.toInt() ?? 8,
    );
  }

  /// Returns a copy pointed at a different speech service (used when the chat
  /// provider turns out to have no transcription endpoint).
  Settings copyWithAsr({required String preset, required String baseUrl, required String model}) {
    asrPreset = preset;
    asrBaseUrl = baseUrl;
    asrModel = model;
    return this;
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _k,
      jsonEncode({
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'persona': persona,
        'memoryEnabled': memoryEnabled,
        'proactiveEnabled': proactiveEnabled,
        'sceneEnabled': sceneEnabled,
        'sceneDim': sceneDim,
        'sceneImage': sceneImage,
        'comfyUrl': comfyUrl,
        'comfyWorkflow': comfyWorkflow,
        'comfyWorkflowRemoveBg': comfyWorkflowRemoveBg,
        'comfyWorkflowEdit': comfyWorkflowEdit,
        'embeddingModel': embeddingModel,
        'asrModel': asrModel,
        'asrPreset': asrPreset,
        'asrLocalModel': asrLocalModel,
        'visionEnabled': visionEnabled,
        'visionProvider': visionProvider,
        'visionBaseUrl': visionBaseUrl,
        'visionApiKey': visionApiKey,
        'visionModel': visionModel,
        'asrBaseUrl': asrBaseUrl,
        'asrApiKey': asrApiKey,
        'provider': provider,
        'apiKeys': apiKeys,
        'ttsEnabled': ttsEnabled,
        'ttsEngine': ttsEngine,
        'ttsSid': ttsSid,
        'ttsSpeed': ttsSpeed,
        'proactiveIdleMinutes': proactiveIdleMinutes,
      }),
    );
  }
}

class Memory {
  static const _k = 'feiyu.memory.v1';
  final List<String> facts = [];

  static Future<Memory> load() async {
    final sp = await SharedPreferences.getInstance();
    final m = Memory();
    m.facts.addAll((sp.getStringList(_k) ?? const []).where((e) => e.trim().isNotEmpty));
    return m;
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_k, facts);
  }

  Future<void> merge(Iterable<String> incoming) async {
    for (final item in incoming) {
      final t = item.trim();
      if (t.isEmpty) continue;
      final dup = facts.any((f) => f == t || (f.length > 8 && t.length > 8 && (f.contains(t) || t.contains(f))));
      if (!dup) facts.add(t);
    }
    while (facts.length > 24) {
      facts.removeAt(0);
    }
    await save();
  }

  String asPrompt() {
    if (facts.isEmpty) return '';
    return '你记得关于主人的这些事（长期记忆，自然使用，不要逐条复述）：\n${facts.map((f) => '- $f').join('\n')}';
  }
}

class _ModelMissing implements Exception {
  @override
  String toString() => '离线语音模型还没下载';
}

class _AsrUnavailable implements Exception {
  final String preset;
  _AsrUnavailable(this.preset);
  @override
  String toString() => '语音服务没有转写接口';
}

class Message {
  final String role;
  String content;
  String? imageBase64;
  final DateTime at;
  Message(this.role, this.content, {this.imageBase64, DateTime? at}) : at = at ?? DateTime.now();

  Map<String, dynamic> toJson() {
    if (imageBase64 == null) return {'role': role, 'content': content};
    return {
      'role': role,
      'content': [
        {'type': 'text', 'text': content},
        {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'}},
      ],
    };
  }

  Map<String, dynamic> toStore() => {
        'role': role,
        'content': content,
        'at': at.toIso8601String(),
        if (imageBase64 != null) 'img': imageBase64,
      };

  static Message fromStore(Map<String, dynamic> j) => Message(
        (j['role'] ?? 'user') as String,
        (j['content'] ?? '') as String,
        imageBase64: j['img'] as String?,
        at: DateTime.tryParse((j['at'] ?? '') as String) ?? DateTime.now(),
      );
}

/// Conversation history that survives restarts.
class ChatStore {
  static const _k = 'feiyu.history.v2';

  static Future<List<Message>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_k) ?? const [];
    final out = <Message>[];
    for (final line in raw) {
      try {
        out.add(Message.fromStore(jsonDecode(line) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  static Future<void> save(List<Message> messages) async {
    final sp = await SharedPreferences.getInstance();
    final keep = messages.length > 200 ? messages.sublist(messages.length - 200) : messages;
    final lines = keep
        .where((m) => m.content.trim().isNotEmpty || m.imageBase64 != null)
        .map((m) => jsonEncode(m.toStore()))
        .toList();
    await sp.setStringList(_k, lines);
  }
}

class FeiyuApp extends StatelessWidget {
  const FeiyuApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '大肥鱼',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const ChatPage(),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Message> _messages = [];
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterTts _tts = FlutterTts();
  bool _recording = false;
  String? _recordPath;
  Memory _memory = Memory();
  Archive _archive = Archive();
  int _summarized = 0;
  List<Footprint> _footprints = const [];

  Settings? _settings;
  bool _busy = false;
  bool _listening = false;
  bool _waitingFirstToken = false;
  String? _error;
  String? _pendingImage;
  String _voiceHint = '';
  http.Client? _client;
  int _turnsSinceDigest = 0;
  String _activity = '';
  DateTime _revealStart = DateTime.now();
  static const _charsPerSecond = 46.0;
  Timer? _idleTimer;
  int _proactiveCount = 0;

  @override
  void initState() {
    super.initState();
    Settings.load().then((s) {
      debugPrint('[feiyu] settings loaded base=${s.baseUrl} model=${s.model} keyLen=${s.apiKey.length}');
      if (mounted) {
        setState(() => _settings = s);
        _resetIdleTimer();
      }
    }).catchError((Object e, StackTrace st) {
      debugPrint('[feiyu] settings load FAILED: $e');
      if (mounted) {
        setState(() {
          _settings = Settings(
            baseUrl: defaultBaseUrl(),
            apiKey: kKeyInjected ? kInjectedKey : '',
            model: kDefaultModel,
            persona: kPresetPersona,
          );
          _error = '读取本地设置失败（已回退默认值）：$e';
        });
      }
    });
    Memory.load().then((m) {
      if (mounted) setState(() => _memory = m);
    }).catchError((Object e) {
      debugPrint('[feiyu] memory load FAILED: $e');
    });
    Archive.load().then((a) {
      if (mounted) setState(() => _archive = a);
    }).catchError((Object e) {
      debugPrint('[feiyu] archive load FAILED: $e');
    });
    FootprintStore.load().then((items) {
      if (mounted) setState(() => _footprints = items);
    }).catchError((Object e) {
      debugPrint('[feiyu] footprints load FAILED: $e');
    });
    ChatStore.load().then((history) {
      if (!mounted || history.isEmpty) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history);
      });
      _scrollToEnd(animate: false);
      debugPrint('[feiyu] restored ${history.length} messages');
    }).catchError((Object e) {
      debugPrint('[feiyu] history load FAILED: $e');
    });
  }

  @override
  void dispose() {
    _client?.close();
    _idleTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _openSettings() async {
    final s = await Navigator.of(context).push<Settings>(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          initial: _settings ??
              Settings(baseUrl: defaultBaseUrl(), apiKey: '', model: kDefaultModel, persona: kPresetPersona),
          memory: _memory,
        ),
      ),
    );
    if (s != null) {
      await s.save();
      setState(() => _settings = s);
    }
  }

  // ---------------- voice ----------------

  Future<void> _toggleVoice() async {
    if (_recording) {
      await _finishRecording();
      return;
    }
    final s = _settings;
    if (s == null) return;
    if (s.apiKey.isEmpty) {
      setState(() => _error = '语音需要先在设置里填 API Key（走网关转写）');
      return;
    }
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = '没有麦克风权限');
        return;
      }
      final dir = await getTemporaryDirectory();
      final local = s.asrPreset == 'local';
      final ext = local ? 'wav' : 'm4a';
      final path = '${dir.path}/feiyu_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final config = local
          ? const RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: 16000,
              numChannels: 1,
            )
          : const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000);
      await _recorder.start(config, path: path);
      setState(() {
        _recording = true;
        _listening = true;
        _recordPath = path;
        _voiceHint = '正在录音…再点一次结束';
        _error = null;
      });
    } catch (e) {
      setState(() {
        _recording = false;
        _listening = false;
        _error = '录音启动失败：$e';
      });
    }
  }

  /// Download the on-device model, showing a simple progress dialog.
  Future<void> _promptModelDownload() async {
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('还要下载离线语音模型'),
        content: const Text(
          'SenseVoice 中文识别模型约 228 MB，只需下载一次，之后完全离线、不花钱。\n\n'
          '下载完就能直接说话，即使断网也认识。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('稍后')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('下载')),
        ],
      ),
    );
    if (go != true || !mounted) return;

    final progress = ValueNotifier<double>(0);
    if (mounted) {
      setState(() => _voiceHint = '正在下载模型…');
    }
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, value, __) => AlertDialog(
          title: const Text('下载离线语音模型'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value == 0 ? null : value),
              const SizedBox(height: 10),
              Text('${(value * 100).round()}%'),
            ],
          ),
        ),
      ),
    ));

    try {
      final engine = await LocalAsrImpl.create(kind: _settings?.asrLocalModel ?? 'dolphin');
      await engine.download(onProgress: (p) => progress.value = p);
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) {
        setState(() => _voiceHint = '模型就绪，可以说话了');
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _voiceHint = '');
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) setState(() => _error = '模型下载失败：$e');
    }
  }

  /// 404 from the transcription endpoint: the preset simply has no such API.
  Future<void> _handleAsrUnavailable() async {
    final s = _settings;
    if (s == null || !mounted) return;
    final switchable = s.asrPreset == 'same';

    if (switchable) {
      // Point her at a service that definitely has /audio/transcriptions.
      final preset = asrById('siliconflow');
      await s.copyWithAsr(
        preset: preset.id,
        baseUrl: preset.baseUrl,
        model: preset.models.first,
      ).save();
      if (mounted) setState(() => _settings = s);
    }

    if (!mounted) return;
    final needsKey = switchable || s.asrApiKey.trim().isEmpty;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('语音识别还没配好'),
        content: Text(
          switchable
              ? '当前厂商没有语音转写接口（404）。\n\n'
                  '已经帮你切到「硅基流动 · SenseVoice」，去设置里填一个它的 API Key 就能用。'
              : '转写接口返回 404，检查设置 → 语音识别里的 Base URL 和模型名。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
          if (needsKey)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openSettings();
              },
              child: const Text('去填 Key'),
            ),
        ],
      ),
    );
  }

  Future<void> _finishRecording() async {
    final s = _settings;
    setState(() {
      _recording = false;
      _voiceHint = '正在转写…';
    });
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    path ??= _recordPath;
    if (path == null || s == null) {
      setState(() {
        _listening = false;
        _voiceHint = '';
      });
      return;
    }
    try {
      final text = await _transcribe(s, path);
      if (!mounted) return;
      if (text != null && text.trim().isNotEmpty) {
        setState(() {
          _listening = false;
          _voiceHint = '';
          _input.text = text.trim();
        });
        await _send();
      } else {
        setState(() {
          _listening = false;
          _voiceHint = '';
          _error = '没听清，要不要再说一次？';
        });
      }
    } on _ModelMissing {
      if (mounted) {
        setState(() {
          _listening = false;
          _voiceHint = '';
          _error = null;
        });
        await _promptModelDownload();
      }
    } on _AsrUnavailable {
      if (mounted) {
        setState(() {
          _listening = false;
          _voiceHint = '';
          _error = null;
        });
        await _handleAsrUnavailable();
      }
    } catch (e) {
      setState(() {
        _listening = false;
        _voiceHint = '';
        _error = '转写失败：$e';
      });
    }
  }

  /// Uploads the clip to the gateway's transcription endpoint.
  Future<String?> _transcribe(Settings s, String path) async {
    if (s.asrPreset == 'local') {
      final engine = await LocalAsrImpl.create(kind: s.asrLocalModel);
      if (!await engine.ready) {
        throw _ModelMissing();
      }
      if (mounted) setState(() => _voiceHint = '识别中…');
      final text = await engine.transcribe(path);
      if (!mounted) return text;
      setState(() => _voiceHint = '');
      if (text == null || text.trim().isEmpty) throw Exception('没听清，再说一次？');
      return text;
    }

    final asrBase = s.asrBaseUrl.trim().isEmpty ? s.baseUrl : s.asrBaseUrl.trim();
    final asrKey = s.asrApiKey.trim().isEmpty ? s.apiKey : s.asrApiKey.trim();
    final base = asrBase.endsWith('/') ? asrBase.substring(0, asrBase.length - 1) : asrBase;
    final req = http.MultipartRequest('POST', Uri.parse('$base/audio/transcriptions'))
      ..headers['authorization'] = 'Bearer $asrKey'
      ..fields['model'] = s.asrModel
      ..fields['language'] = 'zh'
      ..files.add(await http.MultipartFile.fromPath('file', path, filename: 'voice.m4a'));
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 404) {
      throw _AsrUnavailable(s.asrPreset);
    }
    if (streamed.statusCode == 401 || streamed.statusCode == 403) {
      throw Exception('语音服务的 Key 无效（HTTP ${streamed.statusCode}），检查设置里的语音识别 Key');
    }
    if (streamed.statusCode != 200) {
      throw Exception('HTTP ${streamed.statusCode}: ${body.substring(0, body.length.clamp(0, 160))}');
    }
    final j = jsonDecode(body) as Map<String, dynamic>;
    return (j['text'] ?? '') as String?;
  }

  // ---------------- image ----------------

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1280, imageQuality: 82);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _pendingImage = base64Encode(bytes));
    } catch (e) {
      setState(() => _error = '选图失败：$e');
    }
  }

  void _imageSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141F33),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- chat ----------------

  // ---------------- agent loop ----------------

  static const _toolSpecs = [
    {
      'type': 'function',
      'function': {
        'name': 'fetch_url',
        'description': '抓取一个网页的正文文字，用于回答需要上网查资料的问题。只接受 http/https 链接。',
        'parameters': {
          'type': 'object',
          'properties': {
            'url': {'type': 'string', 'description': '完整网址，例如 https://example.com/page'},
          },
          'required': ['url'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'remember',
        'description': '把值得长期记住的一件事写进长期记忆。适合：对方的偏好、约定、正在做的项目、重要经历。'
            '一条只写一个事实，用陈述句，不超过 30 字。',
        'parameters': {
          'type': 'object',
          'properties': {
            'fact': {'type': 'string', 'description': '例如：主人喜欢用机械键盘敲代码'},
          },
          'required': ['fact'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'recall',
        'description': '检索以前聊过的内容（超过最近几十轮的旧对话、往日的摘要）。'
            '当对方问起很久以前的事、或你需要确认某个旧细节时用它。',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': '要查找的关键词或一句话，例如：机械键盘 偏好'},
          },
          'required': ['query'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'draw',
        'description': '在主人电脑上的 ComfyUI 里画一张图并发到对话里。'
            '主人要图片、想让你画点什么、或者需要配图时用它。提示词用英文效果通常更好。',
        'parameters': {
          'type': 'object',
          'properties': {
            'prompt': {'type': 'string', 'description': '画面描述（建议英文）'},
            'negative': {'type': 'string', 'description': '不想要的东西（可选）'},
          },
          'required': ['prompt'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'remove_bg',
        'description': '把对话里最近的一张图片去掉背景（用主人电脑上的 ComfyUI 抠图工作流）。'
            '主人说"去掉背景/抠图/只要人"时用它。',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'edit_image',
        'description': '按主人的要求修改对话里最近的一张图片（改风格、改内容、加东西、换背景等），'
            '用主人电脑上的 ComfyUI 图片编辑工作流。',
        'parameters': {
          'type': 'object',
          'properties': {
            'instruction': {'type': 'string', 'description': '要改成什么样（建议英文）'},
          },
          'required': ['instruction'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'footprint',
        'description': '把这一刻收进「足迹」——只有当你真的觉得这段对话里有值得记住的瞬间时才用：'
            '一次心意、一个新发现、一句戳中的话、一个共同的小胜利。'
            '普通寒暄、查资料、日常问答都不要记。宁可不记，也别凑数。',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': '不超过 12 字的小标题，像日记的抬头'},
            'body': {'type': 'string', 'description': '不超过 60 字，用你自己的口吻写下这个瞬间'},
            'mood': {'type': 'string', 'description': '一个能代表当时心情的表情'},
          },
          'required': ['title', 'body'],
        },
      },
    },
  ];

  String _systemPrompt(Settings s) {
    final now = DateTime.now();
    final today = '${now.year}年${now.month}月${now.day}日 ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return [
      if (s.persona.trim().isNotEmpty) s.persona.trim(),
      '说话方式：像在微信上聊天，不要写文章。'
          '一次最多 1~2 句，口语、短句；想说三件事就分成三条发，用 ||| 分隔（每条 1~2 句，不要编号）。'
          '不要每句都总结，不要"首先/其次/总之"，不要客套收尾。'
          '如果你没把握，就直说"我不确定"，别硬编。',
      '现在是 $today。下面的对话记录可能跨越好几天，注意日期。'
          '如果对方问起以前聊过的事，先看记录和记忆；确实没有就直说没印象，不要编。',
      if (s.memoryEnabled) _memory.asPrompt(),
      _recentDigest(),
      '你可以调用这些工具：'
          '① fetch_url 抓网页正文（查资料、看链接时用，别凭空猜网页内容）；'
          '② remember 把值得长期记住的事记下来（对方的偏好、约定、正在做的项目、重要经历），'
          '一条一句话，不要记流水账；'
          '③ draw 在主人电脑上的 ComfyUI 里画图，画好会自动出现在对话里；'
          '④ remove_bg 去掉对话里最近一张图的背景；⑤ edit_image 按描述修改那张图；'
          '④ footprint 把当下这一刻收进足迹——只有真的打动你、值得多年后回看的瞬间才用，'
          '普通对话不用记。宁可漏记，也不要为了记录而记录。'
          '抓到内容后用自己的话答，别整段照抄。',
    ].where((x) => x.isNotEmpty).join('\n\n');
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _input.text).trim();
    final s = _settings;
    if ((text.isEmpty && _pendingImage == null) || _busy) return;
    if (s == null || s.apiKey.isEmpty || s.baseUrl.isEmpty || s.model.isEmpty) {
      setState(() => _error = '先在右上角设置里填 Base URL、API Key 和模型名');
      return;
    }

    final image = _pendingImage;
    _input.clear();
    unawaited(_tts.stop());
    setState(() {
      _error = null;
      _busy = true;
      _waitingFirstToken = true;
      _pendingImage = null;
      _messages.add(Message('user', text.isEmpty ? '（看这张图）' : text, imageBase64: image));
      _messages.add(Message('assistant', ''));
    });
    _scrollToEnd();
    _revealStart = DateTime.now();
    await _runAgent();
  }

  Future<void> _runAgent() async {
    final s = _settings!;
    final target = _messages.last;
    final convo = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt(s)},
      ...(() {
        // Keep the prompt bounded: long-term knowledge lives in memory facts,
        // so only the most recent exchanges ride along as literal messages.
        final usable = _messages
            .where((m) => m.content.trim().isNotEmpty || m.imageBase64 != null)
            .toList();
        final tail = usable.length > 30 ? usable.sublist(usable.length - 30) : usable;
        final lastImage = tail.lastIndexWhere((m) => m.imageBase64 != null);
        return [
          for (var i = 0; i < tail.length; i++)
            if (i == lastImage || tail[i].imageBase64 == null)
              tail[i].toJson()
            else
              {
                'role': tail[i].role,
                'content': '${tail[i].content}（这里原本有一张图，历史里已省略）',
              },
        ];
      })(),
    ];

    try {
      for (var round = 0; round < 4; round++) {
        final result = await _streamTurn(s, convo, target);
        if (result.toolCalls.isEmpty) break;

        convo.add({'role': 'assistant', 'content': result.text, 'tool_calls': result.toolCalls});
        for (final call in result.toolCalls) {
          final fn = (call['function'] ?? const {}) as Map;
          final name = (fn['name'] ?? '') as String;
          final rawArgs = (fn['arguments'] ?? '{}') as String;
          final id = (call['id'] ?? '') as String;
          String output;
          try {
            final args = (jsonDecode(rawArgs.isEmpty ? '{}' : rawArgs) as Map).cast<String, dynamic>();
            output = await _execTool(name, args);
          } catch (e) {
            output = '工具执行失败：$e';
          }
          convo.add({'role': 'tool', 'tool_call_id': id, 'content': output});
          if (mounted) setState(() => _activity = '');
        }
      }

      await _splitIntoSentences(target);

      _turnsSinceDigest++;
      if (s.memoryEnabled && _turnsSinceDigest >= 3) {
        _turnsSinceDigest = 0;
        unawaited(_digestMemory(s));
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      _client?.close();
      _client = null;
      if (mounted) {
        setState(() {
          _busy = false;
          _waitingFirstToken = false;
          _activity = '';
          if (target.content.trim().isEmpty) _messages.removeLast();
        });
        unawaited(ChatStore.save(_messages));
        if (target.content.trim().isNotEmpty) unawaited(_speak(target.content));
        unawaited(_maybeSummarize(s));
        _resetIdleTimer();
      }
    }
  }

  Future<({String text, List<Map<String, dynamic>> toolCalls})> _streamTurn(
    Settings s,
    List<Map<String, dynamic>> convo,
    Message target,
  ) async {
    // Images need a vision-capable model; everything else stays on the chat one.
    final hasImage = convo.any((m) => m['content'] is List);
    final useVision = hasImage && s.visionEnabled && s.visionBaseUrl.trim().isNotEmpty;
    final rawBase = useVision ? s.visionBaseUrl.trim() : s.baseUrl;
    final apiKey = useVision && s.visionApiKey.trim().isNotEmpty ? s.visionApiKey.trim() : s.apiKey;
    final model = useVision && s.visionModel.trim().isNotEmpty ? s.visionModel.trim() : s.model;

    if (useVision && mounted) setState(() => _activity = '正在看图（$model）…');

    final base = rawBase.endsWith('/') ? rawBase.substring(0, rawBase.length - 1) : rawBase;
    final client = http.Client();
    _client = client;
    final req = http.Request('POST', Uri.parse('$base/chat/completions'))
      ..headers.addAll({
        'content-type': 'application/json',
        'authorization': 'Bearer $apiKey',
      })
      ..body = jsonEncode({
        'model': model,
        'stream': true,
        'messages': convo,
        'tools': _toolSpecs,
        'tool_choice': 'auto',
      });

    final resp = await client.send(req);
    if (resp.statusCode != 200) {
      final body = await resp.stream.bytesToString();
      throw Exception('HTTP ${resp.statusCode}: ${body.length > 300 ? body.substring(0, 300) : body}');
    }

    final buffer = StringBuffer();
    final calls = <int, Map<String, dynamic>>{};
    final done = Completer<void>();
    late StreamSubscription<String> sub;
    sub = resp.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        if (!line.startsWith('data:')) return;
        final data = line.substring(5).trim();
        if (data.isEmpty) return;
        if (data == '[DONE]') {
          if (!done.isCompleted) done.complete();
          return;
        }
        try {
          final j = jsonDecode(data) as Map<String, dynamic>;
          final delta = (j['choices'] as List?)?.first?['delta'] as Map?;
          if (delta == null) return;

          final piece = delta['content'] as String?;
          if (piece != null && piece.isNotEmpty) {
            buffer.write(piece);
            if (mounted) {
              final elapsed = DateTime.now().difference(_revealStart).inMilliseconds;
              final allowed = (elapsed / 1000 * _charsPerSecond).round() + 8;
              final raw = buffer.toString();
              final visible = raw.length > allowed ? raw.substring(0, allowed) : raw;
              setState(() {
                target.content = visible;
                _waitingFirstToken = false;
              });
              _scrollToEnd();
            }
          }

          final tcs = delta['tool_calls'] as List?;
          if (tcs != null) {
            for (final raw in tcs) {
              final tc = raw as Map;
              final idx = (tc['index'] as num?)?.toInt() ?? 0;
              final acc = calls.putIfAbsent(idx, () => {
                    'id': '',
                    'type': 'function',
                    'function': <String, dynamic>{'name': '', 'arguments': ''},
                  });
              if (tc['id'] != null && (acc['id'] as String).isEmpty) acc['id'] = tc['id'];
              final fn = tc['function'] as Map?;
              final fstore = acc['function'] as Map<String, dynamic>;
              if (fn != null) {
                if (fn['name'] != null) fstore['name'] = (fstore['name'] as String) + (fn['name'] as String);
                if (fn['arguments'] != null) {
                  fstore['arguments'] = (fstore['arguments'] as String) + (fn['arguments'] as String);
                }
              }
            }
            if (mounted) setState(() => _activity = '正在查资料…');
          }
        } catch (_) {}
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      onError: (Object e) {
        if (!done.isCompleted) done.completeError(e);
      },
    );

    await done.future.timeout(const Duration(minutes: 5));
    await sub.cancel();

    // Drain whatever the throttle held back, so the message finishes typing out.
    final full = buffer.toString();
    while (mounted && target.content.length < full.length) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) break;
      final elapsed = DateTime.now().difference(_revealStart).inMilliseconds;
      final allowed = (elapsed / 1000 * _charsPerSecond).round() + 8;
      setState(() {
        target.content = full.length > allowed ? full.substring(0, allowed) : full;
      });
      _scrollToEnd();
    }
    client.close();
    _client = null;

    final ordered = (calls.keys.toList()..sort()).map((k) => calls[k]!).toList();
    return (text: buffer.toString(), toolCalls: ordered);
  }

  Future<String> _execTool(String name, Map<String, dynamic> args) async {
    if (name == 'footprint') {
      final title = (args['title'] ?? '').toString().trim();
      final body = (args['body'] ?? '').toString().trim();
      if (title.isEmpty || body.isEmpty) return '足迹需要标题和内容';
      final f = Footprint(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        at: DateTime.now(),
        title: title.length > 20 ? title.substring(0, 20) : title,
        body: body.length > 120 ? body.substring(0, 120) : body,
        mood: (args['mood'] ?? '🐟').toString(),
      );
      final next = [f, ..._footprints];
      if (mounted) setState(() => _footprints = next);
      await FootprintStore.save(next);
      debugPrint('[feiyu] footprint kept: $title');
      return '已收进足迹：$title';
    }
    if (name == 'draw' || name == 'remove_bg' || name == 'edit_image') {
      final s = _settings;
      if (s == null) return '还没设置';

      final isDraw = name == 'draw';
      final prompt = (args['prompt'] ?? args['instruction'] ?? '').toString().trim();
      if (isDraw && prompt.isEmpty) return '要画什么？给我一句画面描述';

      final client = ComfyClient.resolved(s.comfyUrl, web: kIsWeb);
      if (!await client.ping()) {
        return '连不上 ${s.comfyUrl}：检查电脑上的 ComfyUI 是否开着、手机是否同一局域网';
      }

      // Prefer the workflow the owner configured; otherwise build one from the
      // models this ComfyUI actually has, so nothing needs pasting.
      final configured = isDraw
          ? s.comfyWorkflow
          : name == 'remove_bg'
              ? s.comfyWorkflowRemoveBg
              : s.comfyWorkflowEdit;

      Map<String, dynamic> wf;
      if (configured.trim().isNotEmpty) {
        try {
          wf = jsonDecode(configured) as Map<String, dynamic>;
        } catch (e) {
          return '设置里那份工作流 JSON 解析失败：$e';
        }
      } else {
        if (name == 'remove_bg') {
          // ComfyUI-RMBG installed => we can build the graph ourselves.
          final nodes = await client.hasNodes(['RMBG', 'JoinImageWithAlpha']);
          if (!nodes) {
            return '去背景需要 ComfyUI-RMBG 节点（RMBG + JoinImageWithAlpha），'
                '你的 ComfyUI 里没有装，所以这项暂时用不了。';
          }
          wf = defaultRemoveBg();
          debugPrint('[feiyu] auto workflow: background removal');
        } else {
          final ckpts = await client.checkpoints();
          if (ckpts.isEmpty) {
            return '你的 ComfyUI 里一个模型都没有。先在 models/checkpoints 里放一个模型'
                '（比如 SD-Turbo），我就能自己把工作流拼出来。';
          }
          final ckpt = ckpts.first;
          wf = isDraw ? defaultTxt2Img(ckpt) : defaultImg2Img(ckpt);
          debugPrint('[feiyu] auto workflow using $ckpt');
        }
      }

      // Image-in workflows need the newest picture from the conversation.
      String? uploaded;
      if (!isDraw) {
        final src = _lastImageBase64();
        if (src == null) return '对话里还没有图片，先发一张给我';
        if (mounted) setState(() => _activity = '正在上传图片…');
        try {
          uploaded = await client.uploadImage(base64Decode(src));
        } catch (e) {
          if (mounted) setState(() => _activity = '');
          return '图片上传失败：$e';
        }
      }

      final label = isDraw ? '正在作画…' : name == 'remove_bg' ? '正在抠图…' : '正在改图…';
      if (mounted) setState(() => _activity = label);
      try {
        final patched = patchWorkflow(
          wf,
          prompt: prompt,
          negative: (args['negative'] ?? '').toString(),
          seed: DateTime.now().millisecondsSinceEpoch % 1000000007,
          imageName: uploaded,
        );
        final id = await client.submit(patched);
        final images = await client.waitForImages(
          id,
          timeout: const Duration(minutes: 10),
          onTick: (elapsed) {
            if (mounted) setState(() => _activity = '$label ${elapsed.inSeconds}s');
          },
        );
        if (images.isEmpty) return '这次没出图，检查一下 ComfyUI 那边的队列和日志';
        if (mounted) {
          setState(() {
            _activity = '';
            _messages.last.imageBase64 = base64Encode(images.first);
          });
          _scrollToEnd();
          unawaited(ChatStore.save(_messages));
        }
        return isDraw ? '画好了（${images.length} 张）' : '处理好了';
      } catch (e) {
        if (mounted) setState(() => _activity = '');
        return '处理失败：$e';
      }
    }
    if (name == 'recall') {
      final q = (args['query'] ?? '').toString().trim();
      if (q.isEmpty) return '请给出检索关键词';
      if (mounted) setState(() => _activity = '正在翻旧账…');
      final hit = await _recall(q);
      if (mounted) setState(() => _activity = '');
      return hit;
    }
    if (name == 'remember') {
      final fact = (args['fact'] ?? '').toString().trim();
      if (fact.isEmpty) return '没有可记的内容';
      await _memory.merge([fact]);
      if (mounted) setState(() => _activity = '记下了：$fact');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) setState(() => _activity = '');
      return '已记住：$fact';
    }
    if (name != 'fetch_url') return '未知工具：$name';
    final url = (args['url'] ?? '').toString().trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) return '只支持 http/https 链接';
    if (mounted) setState(() => _activity = '正在读网页…');
    try {
      final text = await _fetchPage(url);
      if (mounted) setState(() => _activity = '');
      return text.isEmpty ? '（页面没有可读正文）' : text;
    } catch (e) {
      if (mounted) setState(() => _activity = '');
      return '抓取失败：$e';
    }
  }

  Future<String> _fetchPage(String url) async {
    const limit = 6000;
    if (kIsWeb) {
      // Browsers cannot fetch arbitrary sites (CORS), so the local server does it.
      final proxy = '${Uri.base.origin}/fetch?url=${Uri.encodeComponent(url)}';
      final res = await http.get(Uri.parse(proxy)).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) throw Exception('代理 HTTP ${res.statusCode}');
      final text = utf8.decode(res.bodyBytes, allowMalformed: true);
      return text.length > limit ? text.substring(0, limit) : text;
    }
    final res = await http
        .get(Uri.parse(url), headers: {'user-agent': 'Mozilla/5.0 (compatible; feiyu/1.0)'})
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return _htmlToText(utf8.decode(res.bodyBytes, allowMalformed: true), limit);
  }

  static String _htmlToText(String html, int limit) {
    final text = html
        .replaceAll(RegExp(r'<script.*?</script>', caseSensitive: false, dotAll: true), ' ')
        .replaceAll(RegExp(r'<style.*?</style>', caseSensitive: false, dotAll: true), ' ')
        .replaceAll(RegExp(r'<head.*?</head>', caseSensitive: false, dotAll: true), ' ')
        .replaceAll(RegExp(r'<[^>]+>', dotAll: true), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.length > limit ? text.substring(0, limit) : text;
  }

  // ---------------- proactive ----------------

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    final s = _settings;
    if (s == null || !s.proactiveEnabled) return;
    if (_proactiveCount >= 3) return;
    if (_messages.isEmpty) return;
    _idleTimer = Timer(Duration(minutes: s.proactiveIdleMinutes), _maybeSpeakUp);
  }

  Future<void> _maybeSpeakUp() async {
    final s = _settings;
    if (s == null || !s.proactiveEnabled || _busy || !mounted) return;
    if (_proactiveCount >= 3) return;

    final recent = _messages
        .where((m) => m.content.trim().isNotEmpty)
        .toList()
        .reversed
        .take(6)
        .toList()
        .reversed
        .map((m) => '${m.role == 'user' ? '主人' : '我'}：${m.content}')
        .join('\n');
    if (recent.isEmpty) return;

    try {
      setState(() => _busy = true);
      final base = s.baseUrl.endsWith('/') ? s.baseUrl.substring(0, s.baseUrl.length - 1) : s.baseUrl;
      final res = await http
          .post(
            Uri.parse('$base/chat/completions'),
            headers: {'content-type': 'application/json', 'authorization': 'Bearer ${s.apiKey}'},
            body: jsonEncode({
              'model': s.model,
              'stream': false,
              'messages': [
                {'role': 'system', 'content': _systemPrompt(s)},
                {'role': 'user', 'content': recent},
                {
                  'role': 'system',
                  'content': '主人已经一段时间没说话了。用一句很短的话主动搭个话：可以接着刚才的话题，'
                      '也可以随口分享一点自己的念头。不要问「你在吗」，不要客套，不要超过 30 字。'
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final raw = ((j['choices'] as List).first['message'] as Map)['content'] as String? ?? '';
      final said = raw.trim();
      if (said.isEmpty || !mounted) return;
      setState(() {
        _proactiveCount++;
        _messages.add(Message('assistant', said));
      });
      unawaited(ChatStore.save(_messages));
      _scrollToEnd();
    } catch (_) {
      // Proactive chat is best-effort.
    } finally {
      if (mounted) setState(() => _busy = false);
      _resetIdleTimer();
    }
  }

  Future<void> _digestMemory(Settings s) async {
    try {
      final recent = _messages
          .where((m) => m.content.trim().isNotEmpty)
          .toList()
          .reversed
          .take(10)
          .toList()
          .reversed
          .map((m) => '${m.role == 'user' ? '主人' : '我'}：${m.content}')
          .join('\n');
      if (recent.trim().isEmpty) return;
      final base = s.baseUrl.endsWith('/') ? s.baseUrl.substring(0, s.baseUrl.length - 1) : s.baseUrl;
      final res = await http.post(
        Uri.parse('$base/chat/completions'),
        headers: {'content-type': 'application/json', 'authorization': 'Bearer ${s.apiKey}'},
        body: jsonEncode({
          'model': s.model,
          'stream': false,
          'messages': [
            {
              'role': 'system',
              'content': '从下面这段对话里，只提取关于「主人」的、长期有效的事实（称呼、偏好、习惯、项目、约定）。'
                  '每条一行，不超过 20 字，最多 3 条。没有就输出「无」。不要输出解释。'
            },
            {'role': 'user', 'content': recent},
          ],
        }),
      );
      if (res.statusCode != 200) return;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final raw = ((j['choices'] as List).first['message'] as Map)['content'] as String? ?? '';
      final lines = raw
          .split('\n')
          .map((l) => l.replaceFirst(RegExp(r'^[\-\*\d\.\s]+'), '').trim())
          .where((l) => l.isNotEmpty && l != '无')
          .toList();
      if (lines.isEmpty) return;
      await _memory.merge(lines);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _stop() {
    _client?.close();
    _client = null;
    setState(() {
      _busy = false;
      _waitingFirstToken = false;
    });
  }

  void _clear() => setState(() {
        _messages.clear();
        _error = null;
        unawaited(ChatStore.save(const []));
      });

  /// Visible diagnostics: tells you exactly which piece is missing.
  SceneMood get _mood {
    if (_busy) return _waitingFirstToken ? SceneMood.thinking : SceneMood.speaking;
    if (_listening) return SceneMood.listening;
    return SceneMood.idle;
  }

  String _statusLine() {
    if (_busy) return _activity.isNotEmpty ? _activity : '正在想…';
    final s = _settings;
    if (s == null) return '加载设置中…';
    final keyState = s.apiKey.isEmpty ? 'key✗' : 'key✓${s.apiKey.length}';
    final host = Uri.tryParse(s.baseUrl)?.host ?? s.baseUrl;
    return '${s.model.isEmpty ? '未选模型' : s.model} · $keyState · $host';
  }

  // ---------------- speech out ----------------

  Future<void> _speak(String text) async {
    final s = _settings;
    if (s == null || !s.ttsEnabled || text.trim().isEmpty) return;
    // Long essays get tiring to hear.
    final spoken = text.length > 220 ? '${text.substring(0, 220)}…' : text;

    if (s.ttsEngine == 'local') {
      try {
        final engine = await LocalTtsImpl.create();
        if (!await engine.ready) {
          debugPrint('[feiyu] local tts model missing');
          return;
        }
        final ok = await engine.speak(spoken, sid: s.ttsSid, speed: s.ttsSpeed);
        if (!ok) debugPrint('[feiyu] local tts produced nothing');
        return;
      } catch (e) {
        debugPrint('[feiyu] local tts FAILED: $e');
        return;
      }
    }

    try {
      await _tts.stop();
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.52);
      await _tts.setPitch(1.05);
      await _tts.speak(spoken);
    } catch (e) {
      debugPrint('[feiyu] system tts FAILED: $e');
    }
  }

  /// A person does not send one wall of text. If she used `|||`, deliver each
  /// part as its own message with a small pause in between.
  Future<void> _splitIntoSentences(Message target) async {
    final parts = target.content
        .split('|||')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length <= 1) {
      target.content = parts.isEmpty ? target.content.trim() : parts.first;
      return;
    }

    target.content = parts.first;
    if (mounted) setState(() {});
    _scrollToEnd();

    for (var i = 1; i < parts.length; i++) {
      // Thinking + typing time, roughly like a human writing the next line.
      final wait = Duration(milliseconds: 700 + parts[i].length * 28);
      await Future<void>.delayed(wait);
      if (!mounted) return;
      setState(() => _messages.add(Message('assistant', parts[i])));
      _scrollToEnd();
    }
    if (mounted) unawaited(ChatStore.save(_messages));
  }

  /// The most recent picture the owner sent or that she produced.
  String? _lastImageBase64() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      final img = _messages[i].imageBase64;
      if (img != null && img.isNotEmpty) return img;
    }
    return null;
  }

  // ---------------- memory layers ----------------

  Embedder _embedder(Settings s) =>
      Embedder(baseUrl: s.baseUrl, apiKey: s.apiKey, model: s.embeddingModel);

  /// The last two archive entries of today, always visible to the model.
  String _recentDigest() {
    if (_archive.entries.isEmpty) return '';
    final now = DateTime.now();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final todays = _archive.entries.where((e) => e.day == key).toList();
    final pick = todays.length > 2 ? todays.sublist(todays.length - 2) : todays;
    if (pick.isEmpty) return '';
    return '今天早些时候的摘要：\n${pick.map((e) => '- ${e.text}').join('\n')}';
  }

  /// Compress the backlog into one archive paragraph when it grows too long.
  Future<void> _maybeSummarize(Settings s) async {
    final pending = _messages.length - _summarized;
    if (pending < 20) return;
    final slice = _messages.sublist(_summarized, _messages.length - 4);
    if (slice.isEmpty) return;
    final transcript = slice
        .where((m) => m.content.trim().isNotEmpty)
        .map((m) => '${m.role == 'user' ? '主人' : '我'}：${m.content}')
        .join('\n');
    if (transcript.trim().isEmpty) return;

    try {
      final base = s.baseUrl.endsWith('/') ? s.baseUrl.substring(0, s.baseUrl.length - 1) : s.baseUrl;
      final res = await http
          .post(
            Uri.parse('$base/chat/completions'),
            headers: {'content-type': 'application/json', 'authorization': 'Bearer ${s.apiKey}'},
            body: jsonEncode({
              'model': s.model,
              'stream': false,
              'messages': [
                {
                  'role': 'system',
                  'content': '把这段对话压缩成一段摘要，供以后检索：写清聊了什么、结论或决定、'
                      '以及对方透露的偏好或正在做的事。第三人称，客观，不超过 200 字。不要寒暄。'
                },
                {'role': 'user', 'content': transcript},
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) return;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final summary = ((j['choices'] as List).first['message'] as Map)['content'] as String? ?? '';
      if (summary.trim().isEmpty) return;

      final now = DateTime.now();
      final day = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final vector = await _embedder(s).embed(summary) ?? const <double>[];
      await _archive.add(ArchiveEntry(day: day, text: summary.trim(), vector: vector));
      _summarized = _messages.length - 4;
      debugPrint('[feiyu] archived ${summary.length} chars');
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[feiyu] summarize FAILED: $e');
    }
  }

  Future<String> _recall(String query) async {
    final s = _settings;
    if (s == null) return '还没有设置，无法检索';
    final vector = await _embedder(s).embed(query);
    final hits = _archive.search(vector, query, k: 3);
    if (hits.isEmpty) return '没有找到相关的旧记录';
    return '找到这些旧记录：\n${hits.map((e) => '【${e.day}】${e.text}').join('\n\n')}';
  }

  // ---------------- footprints ----------------

  Future<void> _openComfy() async {
    final s = _settings;
    if (s == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ComfyPage(baseUrl: s.comfyUrl, workflowJson: s.comfyWorkflow),
    ));
  }

  Future<void> _openFootprints() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FootprintsPage(
        items: _footprints,
        onDistill: () async {
          final s = _settings;
          if (s == null) return null;
          final f = await _distillFootprint(s);
          if (f != null) {
            final next = [f, ..._footprints];
            if (mounted) setState(() => _footprints = next);
            await FootprintStore.save(next);
            return f;
          }
          return null;
        },
      ),
    ));
  }

  /// Ask the model to keep exactly one memorable moment from the recent past.
  Future<Footprint?> _distillFootprint(Settings s) async {
    final recent = _messages
        .where((m) => m.content.trim().isNotEmpty)
        .toList()
        .reversed
        .take(16)
        .toList()
        .reversed
        .map((m) => '${m.role == 'user' ? '主人' : '我'}：${m.content}')
        .join('\n');
    if (recent.trim().isEmpty) return null;

    try {
      final base = s.baseUrl.endsWith('/') ? s.baseUrl.substring(0, s.baseUrl.length - 1) : s.baseUrl;
      final res = await http
          .post(
            Uri.parse('$base/chat/completions'),
            headers: {'content-type': 'application/json', 'authorization': 'Bearer ${s.apiKey}'},
            body: jsonEncode({
              'model': s.model,
              'stream': false,
              'messages': [
                {
                  'role': 'system',
                  'content': '从这段对话里挑【一个】值得收藏的瞬间，用大肥鱼的口吻写成一句小记录。'
                      '只输出 JSON：{"title":"不超过12字的小标题","body":"不超过60字的一句话","mood":"一个表情"}。'
                      '如果没有值得记的，只输出 NONE。不要解释。'
                },
                {'role': 'user', 'content': recent},
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final raw = (((j['choices'] as List).first['message'] as Map)['content'] as String? ?? '').trim();
      if (raw.isEmpty || raw.toUpperCase().contains('NONE')) return null;

      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      final map = (jsonDecode(raw.substring(start, end + 1)) as Map).cast<String, dynamic>();
      final title = (map['title'] ?? '').toString().trim();
      final body = (map['body'] ?? '').toString().trim();
      if (title.isEmpty || body.isEmpty) return null;

      final f = Footprint(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        at: DateTime.now(),
        title: title,
        body: body,
        mood: (map['mood'] ?? '🐟').toString(),
      );
      final next = [f, ..._footprints];
      _footprints = next;
      await FootprintStore.save(next);
      debugPrint('[feiyu] footprint kept: $title');
      return f;
    } catch (e) {
      debugPrint('[feiyu] footprint FAILED: $e');
      return null;
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return SceneStage(
      enabled: _settings?.sceneEnabled ?? true,
      dim: _settings?.sceneDim ?? .42,
      image: _settings?.sceneImage ?? '',
      mood: _mood,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: ChatAppBar(
          title: '大肥鱼',
          status: _statusLine(),
          mood: _mood,
          onFootprints: _openFootprints,
          onComfy: _openComfy,
          onNewChat: _clear,
          onSettings: _openSettings,
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: ReadabilityScrim()),
            ContentFrame(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (_error != null) _errorBar(),
                  Expanded(
                    child: _messages.isEmpty ? _emptyState() : _messageList(),
                  ),
                  if (_pendingImage != null) _pendingImageBar(),
                  if (_listening) _listeningBar(),
                  _composer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: InlineNotice(
        tone: NoticeTone.danger,
        message: _error!,
        onDismiss: () => setState(() => _error = null),
      ),
    );
  }

  Widget _emptyState() {
    return EmptyState(
      samples: const ['今天有什么好玩的', '帮我看看这张图', '你还记得我吗'],
      onSample: _send,
      buildTag: kBuildTag,
    );
  }

  Widget _messageList() {
    return MessageList(
      messages: _messages,
      busy: _busy,
      waitingFirstToken: _waitingFirstToken,
      onOpenImage: _openImage,
      controller: _scroll,
    );
  }

  void _openImage(String b64) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: InteractiveViewer(child: Image.memory(base64Decode(b64))),
      ),
    );
  }

  Widget _pendingImageBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(base64Decode(_pendingImage!), width: 54, height: 54, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Text('图片已就绪', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .55))),
          const Spacer(),
          IconButton(onPressed: () => setState(() => _pendingImage = null), icon: const Icon(Icons.close, size: 18)),
        ],
      ),
    );
  }

  Widget _listeningBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Row(
        children: [
          const Icon(Icons.graphic_eq, size: 14, color: Color(0xFF4AA3FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _voiceHint.isEmpty ? '正在听…' : _voiceHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF8FC6FF), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withValues(alpha: .16), Colors.white.withValues(alpha: .06)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: .22)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _busy ? null : _imageSheet,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 22),
                color: Colors.white.withValues(alpha: .6),
                tooltip: '发图片',
              ),
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(fontSize: 14.5),
                  decoration: InputDecoration(
                    hintText: _listening ? '正在听…' : '和大肥鱼说点什么…',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: .3), fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              IconButton(
                onPressed: _busy ? null : _toggleVoice,
                icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none),
                color: _listening ? const Color(0xFF4AA3FF) : Colors.white.withValues(alpha: .6),
                tooltip: _listening ? '停止' : '说话',
              ),
              _busy
                  ? IconButton(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop_circle, color: Color(0xFFFF8A8A)),
                      tooltip: '停止生成',
                    )
                  : Container(
                      margin: const EdgeInsets.only(left: 2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Color(0xFF5AB0FF), Color(0xFF2F6FD0)]),
                      ),
                      child: IconButton(
                        onPressed: _send,
                        icon: const Icon(Icons.arrow_upward, size: 20, color: Color(0xFF04101F)),
                        tooltip: '发送',
                      ),
                    ),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final Settings initial;
  final Memory memory;
  const SettingsPage({super.key, required this.initial, required this.memory});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _base;
  late final TextEditingController _key;
  late final TextEditingController _model;
  late final TextEditingController _persona;
  late bool _memoryEnabled;
  late bool _proactiveEnabled;
  late bool _sceneEnabled;
  late double _sceneDim;
  late String _sceneImage;
  late bool _ttsEnabled;
  late String _ttsEngine;
  late int _ttsSid;
  late double _ttsSpeed;
  bool _ttsModelReady = false;
  String _comfyStatus = '';
  bool _comfyTesting = false;
  bool _downloadingTts = false;
  late String _provider;
  late Map<String, String> _keys;
  late final TextEditingController _asr;
  late final TextEditingController _asrBase;
  late final TextEditingController _asrKey;
  late String _asrPreset;
  late String _asrLocalModel;
  late bool _visionEnabled;
  late final TextEditingController _comfyUrl;
  late final TextEditingController _comfyWorkflow;
  late final TextEditingController _comfyRemoveBg;
  late final TextEditingController _comfyEdit;
  late String _visionProvider;
  late final TextEditingController _visionBase;
  late final TextEditingController _visionKey;
  late final TextEditingController _visionModel;
  late int _proactiveIdleMinutes;
  List<String> _models = const [];
  bool _loadingModels = false;
  String? _modelError;

  @override
  void initState() {
    super.initState();
    _base = TextEditingController(text: widget.initial.baseUrl);
    _key = TextEditingController(text: widget.initial.apiKey);
    _model = TextEditingController(text: widget.initial.model);
    _persona = TextEditingController(text: widget.initial.persona);
    _memoryEnabled = widget.initial.memoryEnabled;
    _proactiveEnabled = widget.initial.proactiveEnabled;
    _sceneEnabled = widget.initial.sceneEnabled;
    _sceneDim = widget.initial.sceneDim;
    _sceneImage = widget.initial.sceneImage;
    _ttsEnabled = widget.initial.ttsEnabled;
    _ttsEngine = widget.initial.ttsEngine;
    _ttsSid = widget.initial.ttsSid;
    _ttsSpeed = widget.initial.ttsSpeed;
    LocalTtsImpl.create().then((e) => e.ready).then((ok) {
      if (mounted) setState(() => _ttsModelReady = ok);
    }).catchError((Object _) {});
    _provider = widget.initial.provider;
    _keys = Map.of(widget.initial.apiKeys);
    _asr = TextEditingController(text: widget.initial.asrModel);
    _asrBase = TextEditingController(text: widget.initial.asrBaseUrl);
    _asrKey = TextEditingController(text: widget.initial.asrApiKey);
    _asrPreset = widget.initial.asrPreset;
    _asrLocalModel = widget.initial.asrLocalModel;
    _visionEnabled = widget.initial.visionEnabled;
    _comfyUrl = TextEditingController(text: widget.initial.comfyUrl);
    _comfyWorkflow = TextEditingController(text: widget.initial.comfyWorkflow);
    _comfyRemoveBg = TextEditingController(text: widget.initial.comfyWorkflowRemoveBg);
    _comfyEdit = TextEditingController(text: widget.initial.comfyWorkflowEdit);
    _visionProvider = widget.initial.visionProvider;
    _visionBase = TextEditingController(text: widget.initial.visionBaseUrl);
    _visionKey = TextEditingController(text: widget.initial.visionApiKey);
    _visionModel = TextEditingController(text: widget.initial.visionModel);
    _proactiveIdleMinutes = widget.initial.proactiveIdleMinutes;
    if (widget.initial.apiKey.trim().isNotEmpty) _loadModels();
  }

  @override
  void dispose() {
    _base.dispose();
    _asr.dispose();
    _asrBase.dispose();
    _asrKey.dispose();
    _visionBase.dispose();
    _visionKey.dispose();
    _visionModel.dispose();
    _comfyUrl.dispose();
    _comfyWorkflow.dispose();
    _comfyRemoveBg.dispose();
    _comfyEdit.dispose();
    _key.dispose();
    _model.dispose();
    _persona.dispose();
    super.dispose();
  }

  /// Every bundled room picture, discovered from the asset manifest.
  Future<List<String>> _sceneChoices() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final rooms = manifest
          .listAssets()
          .where((a) => a.startsWith('assets/scene/room') && a.endsWith('.webp'))
          .toList()
        ..sort();
      return rooms;
    } catch (_) {
      return const [];
    }
  }

  String _sceneLabel(String path) {
    final name = path.split('/').last.replaceAll('.webp', '');
    if (name == 'room') return '房间（默认）';
    return name.replaceFirst('room-', '房间·');
  }

  Future<void> _testComfy() async {
    final url = _comfyUrl.text.trim().isEmpty ? 'http://192.168.1.10:8188' : _comfyUrl.text.trim();
    setState(() {
      _comfyTesting = true;
      _comfyStatus = '正在连接 $url …';
    });
    final client = ComfyClient(url);
    final ok = await client.ping(timeout: const Duration(seconds: 8));
    if (!mounted) return;
    if (ok) {
      final ckpts = await client.checkpoints();
      final nodes = await client.hasNodes(['RMBG']);
      if (!mounted) return;
      setState(() {
        _comfyTesting = false;
        _comfyStatus = '连上了 ✅  模型 ${ckpts.isEmpty ? "无" : ckpts.first}'
            '${nodes ? " · 抠图节点已装" : ""}';
      });
    } else {
      setState(() {
        _comfyTesting = false;
        _comfyStatus = '连不上 ❌ 检查：ComfyUI 是否开着（--listen 0.0.0.0）、'
            '地址是否是这台电脑的局域网 IP、防火墙是否放行 8188';
      });
    }
  }

  Future<void> _downloadTts() async {
    setState(() {
      _downloadingTts = true;
    });
    try {
      final engine = await LocalTtsImpl.create();
      await engine.download();
      final ok = await engine.ready;
      if (mounted) setState(() => _ttsModelReady = ok);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('下载失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _downloadingTts = false);
    }
  }

  Future<void> _loadModels() async {
    setState(() {
      _loadingModels = true;
      _modelError = null;
    });
    try {
      final raw = _base.text.trim();
      final base = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
      final res = await http.get(Uri.parse('$base/models'), headers: {'authorization': 'Bearer ${_key.text.trim()}'});
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final ids = (j['data'] as List).map((e) => (e as Map)['id'].toString()).toList()..sort();
      setState(() {
        _models = ids;
        _loadingModels = false;
      });
    } catch (e) {
      setState(() {
        _loadingModels = false;
        _modelError = '$e';
      });
    }
  }

  void _save() {
    Navigator.of(context).pop(Settings(
      baseUrl: _base.text.trim(),
      apiKey: _key.text.trim(),
      model: _model.text.trim(),
      persona: _persona.text,
      memoryEnabled: _memoryEnabled,
      proactiveEnabled: _proactiveEnabled,
      proactiveIdleMinutes: _proactiveIdleMinutes,
      sceneEnabled: _sceneEnabled,
      sceneDim: _sceneDim,
      sceneImage: _sceneImage,
      ttsEnabled: _ttsEnabled,
      ttsEngine: _ttsEngine,
      ttsSid: _ttsSid,
      ttsSpeed: _ttsSpeed,
      provider: _provider,
      apiKeys: {..._keys, _provider: _key.text.trim()},
      asrModel: _asr.text.trim(),
      asrPreset: _asrPreset,
      asrLocalModel: _asrLocalModel,
      asrBaseUrl: _asrBase.text.trim(),
      asrApiKey: _asrKey.text.trim(),
      visionEnabled: _visionEnabled,
      visionProvider: _visionProvider,
      visionBaseUrl: _visionBase.text.trim(),
      visionApiKey: _visionKey.text.trim(),
      visionModel: _visionModel.text.trim(),
      comfyUrl: _comfyUrl.text.trim().isEmpty ? 'http://192.168.1.10:8188' : _comfyUrl.text.trim(),
      comfyWorkflow: _comfyWorkflow.text,
      comfyWorkflowRemoveBg: _comfyRemoveBg.text,
      comfyWorkflowEdit: _comfyEdit.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF12203A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('自检', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                SelectableText(
                  'build=$kBuildTag\n'
                  'baseUrl=${_base.text}\n'
                  'model=${_model.text}\n'
                  'key长度=${widget.initial.apiKey.length}（注入源长度 ${kKeyInjected ? kInjectedKey.length : 0}）',
                  style: const TextStyle(fontSize: 11, height: 1.5, color: Color(0xFF9FB6D6)),
                ),
              ],
            ),
          ),
          const _Label('厂商'),
          DropdownButtonFormField<String>(
            initialValue: _provider,
            isExpanded: true,
            items: kProviders
                .map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.name}${p.note.isEmpty ? '' : '  ·  ${p.note}'}',
                          overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (id) {
              if (id == null) return;
              final preset = providerById(id);
              setState(() {
                _keys[_provider] = _key.text.trim();
                _provider = id;
                if (preset.baseUrl.isNotEmpty) _base.text = preset.baseUrl;
                if (preset.models.isNotEmpty) _model.text = preset.models.first;
                _key.text = _keys[id] ?? '';
                _models = const [];
              });
              if (_key.text.trim().isNotEmpty) _loadModels();
            },
          ),
          const SizedBox(height: 16),
          const _Label('Base URL（OpenAI 兼容，不带 /chat/completions）'),
          TextField(controller: _base, decoration: const InputDecoration(hintText: 'https://…/v1')),
          const SizedBox(height: 16),
          const _Label('API Key'),
          TextField(
            controller: _key,
            obscureText: true,
            onSubmitted: (_) => _loadModels(),
            onEditingComplete: () {
              if (_key.text.trim().isNotEmpty && _models.isEmpty) _loadModels();
            },
            decoration: InputDecoration(
              hintText: 'sk-…',
              suffixIcon: IconButton(
                onPressed: _loadModels,
                icon: _loadingModels
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 18),
                tooltip: '刷新模型列表',
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _Label('模型'),
          if (_modelError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('拉取模型失败：$_modelError', style: const TextStyle(fontSize: 11, color: Color(0xFFFF9A9A))),
            ),
          Builder(builder: (context) {
            final preset = providerById(_provider);
            final options = _models.isNotEmpty ? _models : preset.models;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: options.contains(_model.text) ? _model.text : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: _models.isEmpty ? '先填 Key（会自动拉取）' : '选择模型',
                    suffixIcon: _loadingModels
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                  items: options
                      .map((id) => DropdownMenuItem(
                            value: id,
                            child: Text(id, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _model.text = v);
                  },
                ),
                if (_models.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text('已从该厂商拉取 ${_models.length} 个模型',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF7FD39A))),
                  ),
              ],
            );
          }),
          const SizedBox(height: 8),
          TextField(
            controller: _model,
            decoration: const InputDecoration(hintText: '也可以手填模型名', isDense: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          const _Label('人设（system prompt）'),
          TextField(controller: _persona, minLines: 5, maxLines: 12),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _memoryEnabled,
            onChanged: (v) => setState(() => _memoryEnabled = v),
            title: const Text('自动记忆'),
            subtitle: const Text('每几轮抽取关于你的长期事实，存在本机'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _ttsEnabled,
            onChanged: (v) => setState(() => _ttsEnabled = v),
            title: const Text('语音朗读'),
            subtitle: const Text('回答完念出来（前三句左右）'),
          ),
          if (_ttsEnabled) ...[
            DropdownButtonFormField<String>(
              initialValue: _ttsEngine,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '发音引擎', isDense: true),
              items: const [
                DropdownMenuItem(value: 'system', child: Text('系统语音（免费、机械）', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'local', child: Text('本机 Kokoro（自然、离线）', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (v) => setState(() => _ttsEngine = v ?? 'system'),
            ),
            if (_ttsEngine == 'local') ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _ttsSid,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '音色', isDense: true),
                items: LocalTtsImpl.voices.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value, style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _ttsSid = v ?? 47),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    const Text('语速：', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Expanded(
                      child: Slider(
                        value: _ttsSpeed,
                        min: 0.6,
                        max: 1.5,
                        divisions: 18,
                        label: _ttsSpeed.toStringAsFixed(2),
                        onChanged: (v) => setState(() => _ttsSpeed = v),
                      ),
                    ),
                    Text(_ttsSpeed.toStringAsFixed(2), style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _downloadingTts ? null : _downloadTts,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(_ttsModelReady ? '模型已就绪（点击重新下载）' : '下载语音模型（约 147 MB）'),
                ),
              ),
            ],
          ],
          const _Label('语音识别服务（录音后上传这里转文字，不用手机自带识别）'),
          DropdownButtonFormField<String>(
            initialValue: _asrPreset,
            isExpanded: true,
            items: kAsrPresets
                .map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name, style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (id) {
              if (id == null) return;
              final p = asrById(id);
              setState(() {
                _asrPreset = id;
                if (p.baseUrl.isNotEmpty) _asrBase.text = p.baseUrl;
                if (p.models.isNotEmpty) _asr.text = p.models.first;
              });
            },
          ),
          if (_asrPreset == 'local') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _asrLocalModel,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '离线模型', isDense: true),
              items: LocalAsrImpl.models.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _asrLocalModel = v ?? 'dolphin'),
            ),
          ],
          if (_asrPreset != 'same' && _asrPreset != 'local') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _asrBase,
              decoration: const InputDecoration(hintText: 'Base URL，例如 https://api.siliconflow.cn/v1', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _asrKey,
              obscureText: true,
              decoration: const InputDecoration(hintText: '语音服务 API Key', isDense: true),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _asr,
            decoration: const InputDecoration(hintText: '转写模型，例如 FunAudioLLM/SenseVoiceSmall', isDense: true),
          ),
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _visionEnabled,
            onChanged: (v) => setState(() => _visionEnabled = v),
            title: const Text('发图时切到看图模型'),
            subtitle: const Text('聊天模型不支持看图时，带图的这一条自动走另一个模型；其余消息仍用原模型'),
          ),
          if (_visionEnabled) ...[
            DropdownButtonFormField<String>(
              initialValue: _visionProvider,
              isExpanded: true,
              items: kProviders
                  .where((p) => p.id != 'custom')
                  .map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (id) {
                if (id == null) return;
                final p = providerById(id);
                setState(() {
                  _visionProvider = id;
                  if (p.baseUrl.isNotEmpty) _visionBase.text = p.baseUrl;
                  if (p.models.isNotEmpty) _visionModel.text = p.models.last.contains('vl') || p.models.last.contains('glm') ? p.models.last : p.models.first;
                });
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _visionBase,
              decoration: const InputDecoration(hintText: 'Base URL', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _visionKey,
              obscureText: true,
              decoration: const InputDecoration(hintText: '看图服务 API Key（留空则用聊天厂商的 Key）', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _visionModel,
              decoration: const InputDecoration(hintText: '看图模型，例如 qwen-vl-max / glm-4.5 / kimi-k3', isDense: true),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 28),
          const _Label('ComfyUI（电脑上的画图服务）'),
          TextField(
            controller: _comfyUrl,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.10:8188',
              isDense: true,
              helperText: '手机和电脑要在同一个局域网；ComfyUI 需以 --listen 0.0.0.0 启动',
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _comfyTesting ? null : _testComfy,
              icon: const Icon(Icons.wifi_tethering, size: 16),
              label: const Text('测试连接', style: TextStyle(fontSize: 12)),
            ),
          ),
          if (_comfyStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _comfyStatus,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF9FD0FF)),
              ),
            ),
          const SizedBox(height: 8),
          const _Label('文生图工作流（她调用 draw 时用）'),
          TextField(
            controller: _comfyWorkflow,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '「Save (API Format)」导出的 JSON',
              isDense: true,
              helperText: '提示词会自动写进采样器的正向/负向输入',
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _comfyWorkflow.text = kComfySdTurboWorkflow;
                if (_comfyUrl.text.trim().isEmpty || _comfyUrl.text.contains('192.168.1.10')) {
                  // convenient for local testing
                }
              }),
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: const Text('填入示例（SD-Turbo）', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 12),
          const _Label('去背景工作流（调用 remove_bg 时用）'),
          TextField(
            controller: _comfyRemoveBg,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '需要一个 LoadImage + 抠图节点 + SaveImage 的工作流',
              isDense: true,
              helperText: '例：ComfyUI-rembg / BRIA RMBG / INSPYRENET 等自定义节点',
            ),
          ),
          const SizedBox(height: 12),
          const _Label('图片编辑工作流（调用 edit_image 时用）'),
          TextField(
            controller: _comfyEdit,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'LoadImage → 编辑节点（img2img / inpaint / Kontext / Qwen-Edit）→ SaveImage',
              isDense: true,
              helperText: '对话里最近一张图会被自动上传并注入 LoadImage',
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _comfyEdit.text = kComfyImg2ImgWorkflow),
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: const Text('填入示例（SD-Turbo img2img）', style: TextStyle(fontSize: 12)),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _sceneEnabled,
            onChanged: (v) => setState(() => _sceneEnabled = v),
            title: const Text('场景模式（背后的房间）'),
            subtitle: const Text('对话浮在房间画面上。往 assets/scene/ 放 room.webp / room.jpg 就能换成自己的房间'),
          ),
          if (_sceneEnabled)
            FutureBuilder<List<String>>(
              future: _sceneChoices(),
              builder: (context, snap) {
                final options = snap.data ?? const <String>[];
                if (options.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DropdownButtonFormField<String>(
                    initialValue: options.contains(_sceneImage)
                        ? _sceneImage
                        : (options.contains('assets/scene/room.webp')
                            ? 'assets/scene/room.webp'
                            : options.first),
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '房间背景', isDense: true),
                    items: options
                        .map((path) => DropdownMenuItem(
                              value: path,
                              child: Text(_sceneLabel(path), style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _sceneImage = v ?? ''),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  const Text('压暗：', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Expanded(
                    child: Slider(
                      value: _sceneDim,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      label: '${(_sceneDim * 100).round()}%',
                      onChanged: (v) => setState(() => _sceneDim = v),
                    ),
                  ),
                  Text('${(_sceneDim * 100).round()}%', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _proactiveEnabled,
            onChanged: (v) => setState(() => _proactiveEnabled = v),
            title: const Text('主动开口'),
            subtitle: Text(_proactiveEnabled
                ? '你有 $_proactiveIdleMinutes 分钟没说话，它会自己搭一句（只在 App 打开时，每场最多 3 次）'
                : '打开后，你不说话时它会主动找你'),
          ),
          if (_proactiveEnabled)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  const Text('空闲触发：', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Expanded(
                    child: Slider(
                      value: _proactiveIdleMinutes.toDouble().clamp(2, 60),
                      min: 2,
                      max: 60,
                      divisions: 29,
                      label: '$_proactiveIdleMinutes 分钟',
                      onChanged: (v) => setState(() => _proactiveIdleMinutes = v.round()),
                    ),
                  ),
                  Text('$_proactiveIdleMinutes 分钟', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          const Divider(height: 28),
          Text('现在记得 ${widget.memory.facts.length} 条', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          ...widget.memory.facts.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('· $f', style: const TextStyle(fontSize: 13)),
              )),
          if (widget.memory.facts.isEmpty)
            const Text('（还没有记忆，多聊几轮就会出现）', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),
          const Text(
            '所有数据只存在这台设备上：Key、对话、记忆都不经过任何第三方服务器。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    );
  }
}
