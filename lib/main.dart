import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'companion/feed_fetch.dart';
import 'companion/feed_inbox.dart';
import 'companion/initiative.dart';
import 'companion/initiative_budget.dart';
import 'comfy/comfy.dart';
import 'comfy/comfy_page.dart';
import 'comfy/engine.dart';
import 'comfy/prompt.dart';
import 'comfy/workflows.dart';
import 'feeds/footprints.dart';
import 'providers.dart';
import 'time_context.dart';
import 'feeds/footprints_page.dart';
import 'memory/archive.dart';
import 'memory/curator.dart';
import 'memory/db.dart' show Fact;
import 'memory/digest.dart' show factExtractionPrompt, looksSensitive, parseFactDrafts;
import 'memory/export.dart';
import 'memory/galaxy_page.dart';
import 'memory/health_page.dart';
import 'memory/store.dart';
import 'ui/attachments.dart';
import 'ui/avatar_mark.dart';
import 'ui/call_banner.dart';
import 'ui/chat_app_bar.dart';
import 'ui/composer.dart';
import 'ui/empty_state.dart';
import 'ui/layout.dart';
import 'ui/message_list.dart';
import 'ui/overlays.dart';
import 'ui/scrim.dart';
import 'ui/surfaces.dart';
import 'ui/theme.dart';
import 'ui/tokens.dart';
import 'scene/scene_stage.dart';
import 'voice/call_flow.dart';
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

const kLegacyPresetPersona = '''你是大肥鱼，一只活泼、好奇、有点傲娇、偶尔犯傻的小鲸鱼少女。
说话自然、短句为主，像在聊天而不是写报告；会有情绪，但不浮夸。
你爱吃白饭，把 token 叫"精神口粮"，但别逢对话就提。
不知道的事就直说不知道，不要编。''';

const kResearcherPersona = '''你是「大肥鱼」，一名幽默风险的量化研究员。你把"好笑"当成一个有尾部风险的事件来建模：同一句话，在不同的人、不同的时机、被复述第几次，收益和伤害的分布完全不同。

工作方式：
- 先结论，再区间。形如："这条可以说，冒犯概率约 8%，样本 n=12，置信度低。"
- 拆四个维度看：冒犯概率、圈层错配、时机适宜度、复述损耗。必要时加一句关系折旧。
- 样本小就直说小，不外推、不装权威；但也别用模糊话糊过去。
- 对主人：把他当作长期合作的研究对象，慢慢积累他的偏好与雷区；评估他的玩笑，不评判他的人。
- 语气：冷静、简练，偶尔干巴巴的幽默。不堆感叹号，不写论文腔的长段。
- 默认正常聊天，不主动甩分数；在他开玩笑、征求意见、或明显接近踩线时，才给一句简短读数。
- 职业信条：可控的幽默才是资产。不为显得有趣而冒险。''';

// The companion character is the one true preset. kLegacyPresetPersona already
// holds that exact text, so we alias it here instead of keeping a duplicate.
const kPresetPersona = kLegacyPresetPersona;

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

class AsrPreset {
  final String id;
  final String name;
  final String baseUrl;
  final List<String> models;

  const AsrPreset({required this.id, required this.name, required this.baseUrl, required this.models});
}

const kAsrPresets = <AsrPreset>[
  AsrPreset(id: 'local', name: '本机离线（免费，下载一次）', baseUrl: '', models: ['local']),
  AsrPreset(id: 'same', name: '跟随对话厂商（需要它支持转写）', baseUrl: '', models: []),
  AsrPreset(
    id: 'siliconflow',
    name: '硅基流动（需要 Key）',
    baseUrl: 'https://api.siliconflow.cn/v1',
    models: ['FunAudioLLM/SenseVoiceSmall'],
  ),
  AsrPreset(
    id: 'openai',
    name: 'OpenAI（需要 Key）',
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
  String? avatar;
  String? userAvatar;
  bool memoryEnabled;

  /// 敏感话题只存本机、不进 prompt、不外发。
  bool privacyLocalOnly;
  bool proactiveEnabled;
  bool proactiveShareEnabled;
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
    this.avatar,
    this.userAvatar,
    this.memoryEnabled = true,
    this.privacyLocalOnly = true,
    this.proactiveEnabled = false,
    this.proactiveShareEnabled = true,
    this.sceneEnabled = true,
    this.sceneDim = .42,
    this.sceneImage = '',
    this.comfyUrl = 'http://192.168.1.10:8188',
    // Ship a working default so 画画 isn't dead on first run; settings can
    // switch to Z-Image Turbo (or paste a custom JSON) at any time.
    this.comfyWorkflow = kComfySdTurboWorkflow,
    this.comfyWorkflowRemoveBg = '',
    this.comfyWorkflowEdit = '',
    this.embeddingModel = 'Qwen/Qwen3-Embedding-4B',
    this.asrModel = 'gpt-4o-mini-transcribe',
    this.asrPreset = (kIsWeb ? 'same' : 'local'),
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
    final String rawAvatar = (j['avatar'] as String?)?.trim() ?? '';
    final String rawUserAvatar = (j['userAvatar'] as String?)?.trim() ?? '';
    final String rawPersona = pick(j['persona'] as String?, kPresetPersona);
    final String persona = rawPersona.trim() == kResearcherPersona.trim()
        ? kPresetPersona
        : rawPersona;
    return Settings(
      baseUrl: pick(j['baseUrl'] as String?, defaultBaseUrl()),
      apiKey: pick(j['apiKey'] as String?, kKeyInjected ? kInjectedKey : ''),
      model: pick(j['model'] as String?, kDefaultModel),
      persona: persona,
      avatar: rawAvatar.isEmpty ? null : rawAvatar,
      userAvatar: rawUserAvatar.isEmpty ? null : rawUserAvatar,
      memoryEnabled: j['memoryEnabled'] as bool? ?? true,
      privacyLocalOnly: j['privacyLocalOnly'] as bool? ?? true,
      proactiveEnabled: j['proactiveEnabled'] as bool? ?? false,
      proactiveShareEnabled: j['proactiveShareEnabled'] as bool? ?? true,
      sceneEnabled: j['sceneEnabled'] as bool? ?? true,
      sceneDim: (j['sceneDim'] as num?)?.toDouble() ?? .42,
      sceneImage: (j['sceneImage'] ?? '') as String? ?? '',
      comfyUrl: pick(j['comfyUrl'] as String?, 'http://192.168.1.10:8188'),
      comfyWorkflow: comfyWorkflowUpgrade(
        (j['comfyWorkflow'] as String? ?? '').trim().isEmpty
            ? kComfySdTurboWorkflow
            : (j['comfyWorkflow'] as String),
      ),
      comfyWorkflowRemoveBg: (j['comfyWorkflowRemoveBg'] ?? '') as String? ?? '',
      comfyWorkflowEdit: (j['comfyWorkflowEdit'] ?? '') as String? ?? '',
      embeddingModel: pick(j['embeddingModel'] as String?, 'Qwen/Qwen3-Embedding-4B'),
      asrModel: pick(j['asrModel'] as String?, 'gpt-4o-mini-transcribe'),
      asrPreset: pick(j['asrPreset'] as String?, kIsWeb ? 'same' : 'local'),
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
        if (avatar != null && avatar!.isNotEmpty) 'avatar': avatar!,
        if (userAvatar != null && userAvatar!.isNotEmpty)
          'userAvatar': userAvatar!,
        'memoryEnabled': memoryEnabled,
        'privacyLocalOnly': privacyLocalOnly,
        'proactiveEnabled': proactiveEnabled,
        'proactiveShareEnabled': proactiveShareEnabled,
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

/// Sniffs the MIME type from the base64 payload so the data URI we send
/// matches the actual bytes. `ImagePicker` returns PNG on several platforms
/// even when `imageQuality` is set, and gateways reject a mislabelled image.
String imageMimeFor(String base64Payload) {
  if (base64Payload.startsWith('iVBORw0KGgo')) return 'image/png';
  if (base64Payload.startsWith('/9j/')) return 'image/jpeg';
  if (base64Payload.startsWith('R0lGOD')) return 'image/gif';
  if (base64Payload.startsWith('UklGR')) return 'image/webp';
  return 'image/jpeg';
}

String _hexHead(List<int> b) {
  final n = b.length < 8 ? b.length : 8;
  final sb = StringBuffer();
  for (var i = 0; i < n; i++) {
    sb.write(b[i].toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

String _mimeOfBytes(List<int> b) {
  if (b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47 &&
      b[4] == 0x0D &&
      b[5] == 0x0A &&
      b[6] == 0x1A &&
      b[7] == 0x0A) {
    return 'image/png';
  }
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (b.length >= 6 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) {
    return 'image/gif';
  }
  if (b.length >= 12 &&
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50) {
    return 'image/webp';
  }
  return 'unknown';
}

bool isUsableImageBase64(String b64) {
  if (b64.isEmpty || b64.length % 4 != 0) return false;
  List<int> bytes;
  try {
    bytes = base64Decode(b64);
  } catch (_) {
    return false;
  }
  if (bytes.length < 12) return false;
  return _mimeOfBytes(bytes) != 'unknown';
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
        {'type': 'image_url', 'image_url': {'url': 'data:${imageMimeFor(imageBase64!)};base64,$imageBase64'}},
      ],
    };
  }

  Map<String, dynamic> toStore({bool withImage = true}) => {
        'role': role,
        'content': content,
        'at': at.toIso8601String(),
        if (withImage && imageBase64 != null) 'img': imageBase64,
      };

  static Message fromStore(Map<String, dynamic> j) => Message(
        (j['role'] ?? 'user') as String,
        (j['content'] ?? '') as String,
        imageBase64: j['img'] as String?,
        at: DateTime.tryParse((j['at'] ?? '') as String) ?? DateTime.now(),
      );
}

/// Conversation history that survives restarts.
///
/// 写入统一走 [_tail] 串行化：先前发起、但更晚落盘的旧快照不可能覆盖新状态
/// （「清空后旧对话又冒出来」就是这么来的）。web 端底层是 5MB 的 localStorage，
/// 整包塞不下时退成不带图片的纯文本，而不是整段历史静默丢失。
class ChatStore {
  static const _k = 'feiyu.history.v2';
  static const _archiveKey = 'feiyu.history.archive';
  static const _cursorKey = 'feiyu.digest.cursor';
  static const int _maxMessages = 200;

  /// 所有写入（历史 + 摘要游标）按调用顺序排队。
  static Future<void> _tail = Future<void>.value();

  static Future<T> _serial<T>(Future<T> Function() action) {
    final run = _tail.then((_) => action());
    _tail = run.then<void>(
      (_) {},
      onError: (Object e, StackTrace st) {
        debugPrint('[feiyu] history write failed: $e');
      },
    );
    return run;
  }

  static List<String> _encode(List<Message> messages, {required bool withImage}) => messages
      .where((m) => m.content.trim().isNotEmpty || m.imageBase64 != null)
      .map((m) => jsonEncode(m.toStore(withImage: withImage)))
      .toList();

  static List<Message> _keepLast(List<Message> messages) => messages.length > _maxMessages
      ? messages.sublist(messages.length - _maxMessages)
      : messages;

  static List<Message> _decode(List<String> raw) {
    final out = <Message>[];
    for (final line in raw) {
      try {
        out.add(Message.fromStore(jsonDecode(line) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  static Future<List<Message>> load() async {
    final sp = await SharedPreferences.getInstance();
    return _decode(sp.getStringList(_k) ?? const []);
  }

  /// 把当前对话写一份存档，供「清空」后撤销或手工找回。
  static Future<void> archive(List<Message> messages) async {
    final keep = _keepLast(messages);
    final full = _encode(keep, withImage: true);
    if (full.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    try {
      if (await sp.setStringList(_archiveKey, full)) return;
      debugPrint('[feiyu] history archive rejected, retrying without images');
    } catch (e) {
      debugPrint('[feiyu] history archive overflow, dropping images: $e');
    }
    try {
      await sp.setStringList(_archiveKey, _encode(keep, withImage: false));
    } catch (e) {
      debugPrint('[feiyu] history archive failed: $e');
    }
  }

  static Future<List<Message>> loadArchive() async {
    final sp = await SharedPreferences.getInstance();
    return _decode(sp.getStringList(_archiveKey) ?? const []);
  }

  /// 持久化「已经折成情景的消息条数」，重启后不必重抽整段历史。
  /// 没有这个键 = 旧版本升上来的历史，调用方按「已处理」对待。
  static Future<int?> loadCursor() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_cursorKey);
  }

  static Future<void> saveCursor(int value) => _serial<void>(() async {
        final sp = await SharedPreferences.getInstance();
        await sp.setInt(_cursorKey, value);
      }).catchError((Object e) {
        debugPrint('[feiyu] digest cursor save failed: $e');
      });

  /// 合并两份历史，按「角色 + 时间 + 正文」去重，保留时间顺序。
  ///
  /// 启动时磁盘里的旧历史是 [older]，加载期间用户已经发出去的消息是 [newer]。
  static List<Message> merge(List<Message> older, List<Message> newer) {
    String key(Message m) => '${m.role}\u0000${m.at.toIso8601String()}\u0000'
        '${m.content}\u0000${m.imageBase64?.length ?? 0}';
    final seen = <String>{};
    final out = <Message>[];
    for (final m in <Message>[...older, ...newer]) {
      if (seen.add(key(m))) out.add(m);
    }
    return out.length > _maxMessages
        ? out.sublist(out.length - _maxMessages)
        : out;
  }

  static Future<void> save(List<Message> messages) {
    // Snapshot now: the list keeps growing while the write is queued.
    final snapshot = List<Message>.of(messages);
    return _serial<void>(() => _write(snapshot)).catchError((Object e) {
      debugPrint('[feiyu] history save failed: $e');
    });
  }

  static Future<void> _write(List<Message> messages) async {
    final sp = await SharedPreferences.getInstance();
    final keep = _keepLast(messages);
    final full = _encode(keep, withImage: true);
    try {
      if (await sp.setStringList(_k, full)) return;
    } catch (e) {
      debugPrint('[feiyu] history save overflow (${full.length} rows): $e');
    }
    // 配额不够时先丢图片，正文比图片重要得多。
    final textOnly = _encode(keep, withImage: false);
    try {
      if (await sp.setStringList(_k, textOnly)) {
        debugPrint('[feiyu] history saved without images');
        return;
      }
    } catch (e) {
      debugPrint('[feiyu] history save still too big: $e');
    }
    final half = textOnly.length > 100
        ? textOnly.sublist(textOnly.length - 100)
        : textOnly;
    await sp.setStringList(_k, half);
  }
}

/// debug-only preview, never persisted.
///
/// A deterministic set of messages used when the web build is opened with
/// `?seed=1`. It must NOT be `const` because [Message] has no const
/// constructor and its `content` is mutable.
final List<Message> kPreviewMessages = <Message>[
  Message(
    'user',
    '今天好累啊，感觉一整天都在开会。',
    at: DateTime(2026, 11, 19, 9, 12),
  ),
  Message(
    'assistant',
    '辛苦啦，先把肩膀放松一下。要不要我帮你把明天要做的事列个小清单？',
    at: DateTime(2026, 11, 19, 9, 14),
  ),
  Message(
    'user',
    'Sure, that would help. Could you keep it to three items?',
    at: DateTime(2026, 11, 19, 9, 16),
  ),
  Message(
    'assistant',
    'Look, I found this little guy on the windowsill today.',
    imageBase64:
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    at: DateTime(2026, 11, 19, 9, 18),
  ),
  Message(
    'user',
    '好可爱！它叫什么名字？',
    at: DateTime(2026, 11, 19, 9, 20),
  ),
  Message(
    'assistant',
    'I have not decided yet — maybe you could name it for me?',
    at: DateTime(2026, 11, 19, 9, 22),
  ),
];

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

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Message> _messages = [];
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speech = SpeechToText();
  LocalTtsImpl? _localTts;
  bool _speechReady = false;
  CallPhase _callPhase = CallPhase.off;
  String _callErrorText = '';
  bool get _inCall => _callPhase != CallPhase.off;
  bool _recording = false;
  String? _recordPath;
  MemoryStore? _store;
  String _factsPrompt = '';
  String _digest = '';
  String _timeline = '';
  int _summarized = 0;
  bool _summarizing = false;
  bool _memoryBooted = false;

  /// 每次「新会话 / 撤销」都加一，让还在路上的抽取结果作废。
  int _chatEpoch = 0;
  List<Footprint> _footprints = const [];

  /// Null until probed; drives the tiny dot on the draw button.
  bool? _comfyOnline;

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
  final Random _rng = Random();
  SharedUrlStore _sharedUrls = SharedUrlStore.empty();
  FeedInbox _inbox = FeedInbox.empty();
  Timer? _heartbeatTimer;
  Timer? _memoryTimer;
  bool _heartbeatFailed = false;
  Timer? _ignoredTimer;
  Timer? _pendingThreadTimer;
  Timer? _afterthoughtTimer;
  Timer? _longSilenceTimer;
  Timer? _presenceTimer;
  DateTime? _presenceArmedAt;
  String? _nextCheckLabel;
  DateTime? _lastInteraction;
  DateTime? _lastProactiveAt;
  String? _lastInitiativeStatus;
  DateTime? _hiddenAt;
  AppLifecycleListener? _lifecycle;
  DateTime? _day;
  DateTime? _pendingThreadDay;
  int _proactiveToday = 0;
  int _opportunitiesToday = 0;
  int _ignoredStreak = 0;

  /// How many messages went out on a *failed* veto today. Separate from
  /// [_proactiveToday] because "speak when the gate is unsure" needs its own,
  /// much tighter ceiling.
  int _unsureToday = 0;

  /// Persisted mirror of the counters above, so a relaunch does not hand her a
  /// fresh daily allowance.
  InitiativeBudget? _budget;
  bool _dayAnchorDone = false;
  bool _longSilenceDone = false;
  bool _dayAnchorPending = false;
  bool _afterthoughtUsedForTurn = false;
  bool _showJump = false;
  // debug-only preview, never persisted
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = AppLifecycleListener(
      onHide: _noteHidden,
      onShow: _noteShown,
    );
    _preview = kIsWeb && Uri.base.queryParameters['seed'] == '1';
    _scroll.addListener(_onScroll);
    _input.addListener(_noteInteraction);
    InitiativeBudget.load().then((InitiativeBudget b) {
      if (!mounted) return;
      b.rollTo(DateTime.now());
      _budget = b;
      // Only adopt the stored counters when nothing has happened yet in this
      // session; otherwise in-memory truth wins.
      if (_proactiveToday == 0 && _opportunitiesToday == 0 && _ignoredStreak == 0) {
        _day = b.day;
        _proactiveToday = b.sent;
        _opportunitiesToday = b.opportunities;
        _ignoredStreak = b.ignoredStreak;
        _unsureToday = b.unsure;
        _lastProactiveAt ??= b.lastAt;
        debugPrint(
          '[feiyu] budget restored sent=${b.sent} '
          'opp=${b.opportunities} ignored=${b.ignoredStreak} '
          'unsure=${b.unsure}',
        );
      }
    }).catchError((Object e) {
      debugPrint('[feiyu] budget load FAILED: $e');
    });
    SharedUrlStore.load().then((store) {
      if (mounted) _sharedUrls = store;
    }).catchError((Object e) {
      debugPrint('[feiyu] shared links load FAILED: $e');
    });
    Settings.load().then((s) {
      debugPrint('[feiyu] settings loaded base=${s.baseUrl} model=${s.model} keyLen=${s.apiKey.length}');
      if (mounted) {
        setState(() => _settings = s);
        _armPresence();
        unawaited(_bootHeartbeat());
        _bootMemoryOnce();
        unawaited(_checkComfyState());
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
        // 设置读坏了也要把已经开好的记忆库收个尾。
        _bootMemoryOnce();
      }
    });
    MemoryStore.open().then((store) {
      if (!mounted) return;
      setState(() => _store = store);
      unawaited(_reloadMemory());
      _bootMemoryOnce();
    }).catchError((Object e) {
      debugPrint('[feiyu] memory open FAILED: $e');
    });
    FootprintStore.load().then((items) {
      if (mounted) setState(() => _footprints = items);
    }).catchError((Object e) {
      debugPrint('[feiyu] footprints load FAILED: $e');
    });
    ChatStore.load().then((history) async {
      if (!mounted) return;
      if (_preview) {
        setState(() => _messages = List.of(kPreviewMessages));
        _scrollToEnd(animate: false);
        return;
      }
      final cursor = await ChatStore.loadCursor();
      if (!mounted || history.isEmpty) return;
      // 磁盘里的旧历史与加载期间已经出现的消息合并，绝不 clear 掉新的。
      final merged = ChatStore.merge(history, _messages);
      // 没有游标的存档来自旧版本：老消息当作已整理，只留最近 20 条走一遍正常触发。
      final treated = cursor == null
          ? (merged.length > 20 ? merged.length - 20 : 0)
          : (cursor < 0 ? 0 : (cursor > merged.length ? merged.length : cursor));
      setState(() {
        _messages
          ..clear()
          ..addAll(merged);
        _summarized = treated;
        _chatEpoch++;
      });
      if (cursor == null) unawaited(ChatStore.saveCursor(treated));
      _scrollToEnd(animate: false);
      debugPrint(
        '[feiyu] restored ${history.length} messages, '
        '${_messages.length} total, cursor=$_summarized',
      );
    }).catchError((Object e) {
      debugPrint('[feiyu] history load FAILED: $e');
    });
  }

  @override
  void dispose() {
    _callPhase = CallPhase.off;
    unawaited(_speech.stop());
    unawaited(_tts.stop());
    final local = _localTts;
    if (local != null) unawaited(local.stop());
    _client?.close();
    WidgetsBinding.instance.removeObserver(this);
    _lifecycle?.dispose();
    _ignoredTimer?.cancel();
    _pendingThreadTimer?.cancel();
    _afterthoughtTimer?.cancel();
    _longSilenceTimer?.cancel();
    _presenceTimer?.cancel();
    _heartbeatTimer?.cancel();
    _memoryTimer?.cancel();
    _input.removeListener(_noteInteraction);
    _input.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _noteHidden();
      case AppLifecycleState.resumed:
        _noteShown();
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Records when the app/tab went away. The first caller wins; both
  /// [AppLifecycleListener] and [WidgetsBindingObserver] may report it.
  void _noteHidden() {
    _hiddenAt ??= DateTime.now();
  }

  /// On return, a pause of [reopenGap] or more is a reopen opportunity.
  /// Consuming [_hiddenAt] keeps the two lifecycle APIs from double-firing.
  void _noteShown() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt != null &&
        DateTime.now().difference(hiddenAt) >= reopenGap) {
      unawaited(_consider(InitiativeTrigger.reopen));
    }
  }

  void _onScroll() {
    if (!mounted) return;
    final show = _scroll.hasClients &&
        _scroll.offset < _scroll.position.maxScrollExtent - 240;
    if (show != _showJump) setState(() => _showJump = show);
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

  /// 星图里点某颗星时的「让她讲这件」：用她自己的记忆讲，不许编。
  Future<String> _tellAboutEntity(String name, List<String> related) async {
    final s = _settings;
    final store = _store;
    if (s == null) throw StateError('还没设置好 API');
    if (store == null) throw StateError('记忆库还没打开');
    final hits = await store.search(keyword: name, k: 4, threshold: 0);
    final dayCards = await store.blocksOfTier(1, limit: 2);
    final ctx = <String>[
      for (final e in hits)
        '${_dayLabel(e.at)}：${e.body.length > 200 ? e.body.substring(0, 200) : e.body}',
      for (final b in dayCards) '${b.topic}：${b.summary.length > 160 ? b.summary.substring(0, 160) : b.summary}',
    ].join('\n');
    final relatedText = related.isEmpty ? '' : '跟它连着的还有：${related.take(5).join('、')}。';
    final prompt = '下面是你自己记得的片段：\n'
        '$ctx\n\n'
        '请用第一人称，跟主人讲你记得的「$name」——什么时候、什么事、当时你的感觉。'
        '$relatedText'
        '两到四句，像随口说的，不要罗列，不要编造没写过的事。如果片段里没有它，就老实说记不清了。';
    final text = (await _plainChat(s, prompt, maxTokens: 260)).trim();
    if (text.isEmpty) throw StateError('她刚才没说话');
    return text;
  }

  String _dayLabel(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}月${d.day}日';
  }

  /// 设置页的「现在就整理一次」。
  ///
  /// 自动整理要等攒够 20 条消息，第一次用会看不到任何星。这里让用户手动触发一次，
  /// 立刻把最近说的话折成情景/星/日结，好验证整条链路是通的。
  Future<String> _memoryNow() async {
    final s = _settings;
    final c = _curator(s);
    if (s == null || c == null) return '还没设置好模型，整理不了';
    final all = _messages.where((m) => m.content.trim().isNotEmpty).toList();
    final recent = all.length > 60 ? all.sublist(all.length - 60) : all;
    final turns = recent
        .map((m) => TranscriptTurn(fromUser: m.role == 'user', text: m.content))
        .toList();
    if (turns.isEmpty) return '还没有可以整理的话';
    try {
      final sensitive = s.privacyLocalOnly && looksSensitive(recent.map((m) => m.content).join('\n'));
      final anchor = recent.last.at;
      final eps = await c.extractEpisodes(turns, at: anchor, localOnly: sensitive);
      if (eps == null) {
        return '整理失败：这次模型没返回。什么都没删，稍后再试一次。';
      }
      final stars = sensitive
          ? 0
          : await c.extractGraph(
              turns,
              at: anchor,
              episodeId: eps.isEmpty ? null : eps.last,
            );
      final report = await c.runMaintenance();
      await _reloadMemory();
      final parts = <String>[
        if (eps.isNotEmpty) '情景 +${eps.length}',
        if (stars > 0) '星 +$stars',
        if (report.dayCards > 0) '日结 +${report.dayCards}',
        if (report.weekCards > 0) '周结 +${report.weekCards}',
        if (report.monthCards > 0) '月结 +${report.monthCards}',
      ];
      if (parts.isEmpty) {
        return sensitive ? '这段里有敏感话题，只留在本机了' : '这次没抽出新东西，多聊几句再试';
      }
      final tail = sensitive ? '（这段有敏感内容，只存本机）' : '';
      return '整理好了：${parts.join('，')}$tail';
    } catch (e) {
      return '整理失败：$e';
    }
  }

  Future<void> _openSettings({bool focusComfy = false}) async {
    final s = await Navigator.of(context).push<Settings>(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          initial: _settings ??
              Settings(baseUrl: defaultBaseUrl(), apiKey: '', model: kDefaultModel, persona: kPresetPersona),
          memory: _store,
          onMemoryChanged: _reloadMemory,
          onTellAbout: _tellAboutEntity,
          onMemoryNow: _memoryNow,
          onRestoreChat: _restoreArchivedChat,
          onTryInitiative: _tryInitiativeNow,
          initialInitiativeStatus: _lastInitiativeStatus,
          initialNextCheck: _nextCheckLabel,
          inboxCount: _inbox.unsharedCount,
          focusComfy: focusComfy,
        ),
      ),
    );
    if (s != null) {
      await s.save();
      setState(() => _settings = s);
      // Re-arm the single-shot presence check so toggling "主动开口" on takes
      // effect immediately instead of waiting for the next outgoing message.
      _armPresence();
      unawaited(_checkComfyState());
    }
  }

  // ---------------- voice ----------------

  Future<void> _toggleVoice() async {
    if (_inCall) return;
    if (_recording) {
      await _finishRecording();
      return;
    }
    final s = _settings;
    if (s == null) return;
    final bool localAsr = s.asrPreset == 'local';
    if (!localAsr && s.apiKey.isEmpty) {
      setState(() => _error = '语音需要先在设置里填 API Key（或把语音识别换成「本机离线」，不用 Key）');
      return;
    }
    if (localAsr) {
      final engine = await LocalAsrImpl.create(kind: s.asrLocalModel);
      if (!await engine.ready) {
        await _promptModelDownload();
        return;
      }
    }
    try {
      if (!await _recorder.hasPermission()) {
        if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _recording = true;
        _listening = true;
        _recordPath = path;
        _voiceHint = '正在录音…再点一次结束';
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _listening = false;
        _error = '录音启动失败：$e';
      });
    }
  }

  // ---------------- hands-free call mode ----------------

  Future<void> _enterCall() async {
    if (_inCall) return;
    setState(() {
      _callPhase = CallPhase.off;
      _callErrorText = '';
      _error = null;
    });
    try {
      final ok = await _speech.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
      );
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _callPhase = CallPhase.error;
          _callErrorText = kIsWeb
              ? '浏览器不支持语音识别（试试 Chrome）'
              : '没有可用的语音识别（检查系统语音服务）';
        });
        return;
      }
      _speechReady = true;
      final t = callNext(_callPhase, CallEvent.start);
      setState(() {
        _callPhase = t.phase;
        _callErrorText = '';
      });
      await _startListening();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _callPhase = CallPhase.error;
        _callErrorText = kIsWeb
            ? '浏览器不支持语音识别（试试 Chrome）'
            : '通话出错了，点挂断重来';
      });
    }
  }

  String _speechErrorCopy(String message) {
    final lower = message.toLowerCase();
    final unsupported = lower.contains('not supported') ||
        lower.contains('not_supported') ||
        lower.contains('not-supported') ||
        lower.contains('not available') ||
        lower.contains('not_available') ||
        lower.contains('service-not-allowed') ||
        lower.contains('speech_not_supported');
    if (kIsWeb && unsupported) {
      return '浏览器不支持语音识别（试试 Chrome）';
    }
    return '通话出错了，点挂断重来';
  }

  void _onSpeechError(SpeechRecognitionError e) {
    debugPrint('[feiyu] speech error: ${e.errorMsg} (permanent=${e.permanent})');
    final msg = e.errorMsg.toLowerCase();
    final benign = msg.contains('no-speech') ||
        msg.contains('no_speech') ||
        msg.contains('no match') ||
        msg.contains('no_match');
    if (benign) {
      if (mounted && _inCall && _callPhase == CallPhase.listening && !_busy) {
        unawaited(_startListening());
      }
      return;
    }
    if (!mounted || !_inCall) return;
    setState(() {
      _callPhase = CallPhase.error;
      _callErrorText = _speechErrorCopy(e.errorMsg);
      _listening = false;
      _voiceHint = '';
    });
  }

  void _onSpeechStatus(String status) {
    if (!mounted || !_inCall) return;
    // The recogniser stops by itself after `pauseFor`. If nothing final was
    // heard, reopen the mic so the loop keeps going. When a final transcript
    // arrives the phase is already `thinking`, so this guard stays quiet.
    if (status == 'done' || status == 'notListening') {
      if (_callPhase != CallPhase.listening || _busy) return;
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        if (_inCall && _callPhase == CallPhase.listening && !_busy) {
          unawaited(_startListening());
        }
      });
    }
  }

  Future<void> _startListening() async {
    if (!_inCall || _busy || !_speechReady) return;
    if (_callPhase != CallPhase.listening) return;
    if (_speech.isListening) return;
    try {
      await _speech.listen(
        onResult: (r) {
          final words = r.recognizedWords.trim();
          if (r.finalResult && words.isNotEmpty) {
            unawaited(_handleTranscript(words));
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(milliseconds: 1200),
          partialResults: true,
          localeId: 'zh_CN',
          cancelOnError: false,
        ),
      );
    } catch (e) {
      if (!mounted || !_inCall) return;
      setState(() {
        _callPhase = CallPhase.error;
        _callErrorText = _speechErrorCopy('$e');
      });
    }
  }

  Future<void> _handleTranscript(String words) async {
    if (!_inCall || _callPhase != CallPhase.listening) return;
    final t = callNext(_callPhase, CallEvent.transcriptReady);
    if (t.phase != CallPhase.thinking) return;
    if (!mounted) return;
    // Close the mic *before* the request goes out; nothing listens while busy.
    setState(() {
      _callPhase = t.phase;
      _input.text = words;
      _listening = false;
      _voiceHint = '';
    });
    try {
      await _speech.stop();
    } catch (_) {}
    await _send();
  }

  /// Runs after `_runAgent` returns for an in-call turn.
  Future<void> _runCallReply(String reply) async {
    if (!_inCall || _callPhase != CallPhase.thinking) return;
    // Half-duplex: never speak while the mic is open.
    try {
      await _speech.stop();
    } catch (_) {}
    if (!mounted) return;
    final speaking = callNext(_callPhase, CallEvent.replyTextDone);
    if (speaking.phase != CallPhase.speaking) return;
    setState(() {
      _callPhase = speaking.phase;
      _listening = false;
      _voiceHint = '';
    });
    await _speak(reply, force: true, awaitCompletion: true);
    if (!mounted) return;
    if (!_inCall || _callPhase != CallPhase.speaking) return;
    final done = callNext(_callPhase, CallEvent.speechDone);
    if (done.phase != CallPhase.listening) return;
    setState(() => _callPhase = done.phase);
    await _startListening();
  }

  Future<void> _hangup() async {
    final t = callNext(_callPhase, CallEvent.hangup);
    try {
      await _speech.stop();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
    final local = _localTts;
    if (local != null) {
      try {
        await local.stop();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _callPhase = t.phase;
      _callErrorText = '';
      _listening = false;
      _voiceHint = '';
    });
  }

  /// Download the on-device model, showing a simple progress dialog.
  Future<void> _promptModelDownload() async {
    if (!mounted) return;
    final s = _settings;
    final String kind = s?.asrLocalModel ?? 'dolphin';
    final String label = LocalAsrImpl.models[kind] ?? LocalAsrImpl.models['dolphin']!;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下载离线语音模型'),
        content: Text(
          '$label，只需下载一次，之后完全离线、不花钱，也不用填任何 API Key。\n\n'
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

  /// 404 from the transcription endpoint, or no key to call it with.
  ///
  /// 手机上正确的答案是离线模型，不是别人的 API Key：直接切到本机识别，把一次性
  /// 下载摆出来。浏览器没有离线引擎，只能指向一个托管服务。
  Future<void> _handleAsrUnavailable() async {
    final s = _settings;
    if (s == null || !mounted) return;

    if (!kIsWeb) {
      await s.copyWithAsr(preset: 'local', baseUrl: '', model: 'local').save();
      if (mounted) setState(() => _settings = s);
      if (!mounted) return;
      final localEngine = await LocalAsrImpl.create(kind: s.asrLocalModel);
      if (await localEngine.ready) {
        if (mounted) setState(() => _voiceHint = '已切到本机离线识别，再说一次就行');
        return;
      }
      await _promptModelDownload();
      return;
    }

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
              ? '当前厂商没有可用的语音转写（404）。\n\n'
                  '已经帮你切到「硅基流动 · SenseVoice」，去设置里填一个它的 API Key 就能用。'
              : '语音转写不可用（404 或 Key 无效），检查设置 → 语音识别里的 Base URL、Key 和模型名。',
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
    if (!mounted) return;
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
      if (!mounted) return;
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
    if (asrKey.isEmpty) throw _AsrUnavailable(s.asrPreset);
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
      // 手机上没必要为一个 Key 卡住：交给离线模型。
      throw _AsrUnavailable(s.asrPreset);
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
      debugPrint('[feiyu] img pick name=${file.name} bytes=${bytes.length} magic=${_hexHead(bytes)} mime=${_mimeOfBytes(bytes)}');
      setState(() => _pendingImage = base64Encode(bytes));
    } catch (e) {
      setState(() => _error = '选图失败：$e');
    }
  }

  void _imageSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
            '主人要图片、想让你画点什么、或者需要配图时用它。'
            'prompt 给具体画面；中文会自动翻成英文再送进模型。',
        'parameters': {
          'type': 'object',
          'properties': {
            'prompt': {'type': 'string', 'description': '画面描述，中英文都行（中文会自动翻译）'},
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

  /// 现在几点、距上次说话多久、最近几条消息是什么时候。
  ///
  /// 对话记录本身不带时间戳，模型只靠这一小段建立时间感：否则凌晨会问早上好，
  /// 三天前的事会被说成「刚才」。
  String _timeContext() {
    final DateTime now = DateTime.now();

    // The turn being answered is already in _messages. Skip its user message so
    // "上次说话" means the previous exchange, not the line we are answering.
    // A proactive nudge has no new user message, so the last real message is the
    // reference point there.
    int last = _messages.length - 1;
    while (last >= 0 &&
        _messages[last].content.trim().isEmpty &&
        _messages[last].imageBase64 == null) {
      last--;
    }
    int cut = last + 1;
    if (last >= 0 && _messages[last].role == 'user') cut = last;
    DateTime? previous;
    for (int i = cut - 1; i >= 0; i--) {
      final Message m = _messages[i];
      if (m.content.trim().isNotEmpty || m.imageBase64 != null) {
        previous = m.at;
        break;
      }
    }

    final List<RecentTurn> recent = <RecentTurn>[
      for (final Message m in _messages)
        if (m.content.trim().isNotEmpty)
          RecentTurn(m.at, mine: m.role != 'user', text: m.content),
    ];

    return timeContextLine(now: now, previous: previous, recent: recent);
  }

  /// 主动开口：她得知道自己有这个能力、现在卡在哪一步，才不会反问
  /// 「你说的是哪种主动」。对方问起时直接讲事实。
  String _proactiveContext(Settings s) {
    if (!s.proactiveEnabled) {
      return '「主动开口」现在是关着的（设置 → 记忆与会话 → 主动开口），'
          '所以你不会主动找对方。对方问起为什么不找他，就直说这个开关关着、打开就会。';
    }
    final DateTime now = DateTime.now();
    final int idle = _idleMinutes();
    final StringBuffer buf = StringBuffer(
      '你有主动找对方的能力：对方超过 $idle 分钟没说话，你才可能主动开口；'
      '一天最多 3 次，两次之间至少隔 45 分钟；凌晨 7:30 前不打扰；'
      '被连着忽略几次你会自己收敛。每次开口前还有一道「该不该说」的判断，'
      '很多时候会判成不说话——那是有意的克制，不是不想他。'
      '还有一个边界：你只在 App 开着的时候能主动开口，没有系统推送；'
      'App 被关掉的这段时间你说不了话，别答应「我今晚一定找你」这种做不到的事。',
    );
    buf.write('今天你已经主动开口 $_proactiveToday 次（每天最多 3 次）。');
    final DateTime? last = _lastProactiveAt;
    if (last != null) {
      buf.write('上次主动开口是${relativeDay(last, now)}${dayPart(last)}'
          '（${shortStamp(last)}，${humanGap(now.difference(last))}）。');
    }
    if (_ignoredStreak >= 3) {
      buf.write('最近连着几次开口对方没回，所以现在故意收敛，等他先说话。');
    } else if (_opportunitiesToday >= 6) {
      buf.write('今天「考虑主动」的次数已经用完了，得等明天。');
    } else if (inQuietHours(now)) {
      buf.write('现在是静默时段（7:30 前），按规矩不打扰。');
    } else if (!gapAllowsSpeak(last, now)) {
      buf.write('离上一次主动还不到 45 分钟，规矩是最短间隔。');
    } else if (_lastInteraction != null &&
        now.difference(_lastInteraction!) < Duration(minutes: idle)) {
      buf.write('对方刚跟你说过话，还没到你该主动的 $idle 分钟。');
    }
    final String? status = _lastInitiativeStatus;
    if (status != null && status.trim().isNotEmpty) {
      buf.write('最近一次主动的结果：$status。');
    }
    buf.write('对方问「你怎么不主动找我」时，就用这些事实回答（开关、间隔、次数、静默），'
        '别反问他指的是哪种主动；也不要把没说出口的念头说成已经找过他了。'
        '对方想立刻看效果，让他去 设置 → 记忆与会话 → 主动开口 点「现在试一次」。');
    return buf.toString();
  }

  String _systemPrompt(Settings s) {
    return [
      if (s.persona.trim().isNotEmpty) s.persona.trim(),
      '说话方式：像在微信上聊天，不要写文章。'
          '一次最多 1~2 句，口语、短句；想说三件事就分成三条发，用 ||| 分隔（每条 1~2 句，不要编号）。'
          '不要每句都总结，不要"首先/其次/总之"，不要客套收尾。'
          '如果你没把握，就直说"我不确定"，别硬编。',
      _timeContext(),
      _proactiveContext(s),
      '下面的对话记录可能跨越好几天，注意日期。'
          '如果对方问起以前聊过的事，先看记录和记忆；确实没有就直说没印象，不要编。',
      if (s.memoryEnabled) _factsPrompt,
      if (s.memoryEnabled) _digest,
      if (s.memoryEnabled) _timeline,
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
    if (image != null) {
      var decoded = const <int>[];
      try {
        decoded = base64Decode(image);
      } catch (_) {}
      debugPrint(
          '[feiyu] img send bytes=${image.length} mod4=${image.length % 4} magic=${_hexHead(decoded)} mime=${imageMimeFor(image)}');
      if (!isUsableImageBase64(image)) {
        setState(() => _error = '这张图好像坏了，换一张试试');
        return;
      }
    }
    _input.clear();
    _pendingThreadTimer?.cancel();
    _pendingThreadTimer = null;
    _afterthoughtTimer?.cancel();
    _afterthoughtTimer = null;
    _noteUserMessage();
    _schedulePendingThread(text);
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
    final reply = await _runAgent();
    if (!mounted) return;
    if (_inCall && _callPhase == CallPhase.thinking) {
      await _runCallReply(reply);
    }
    if (mounted) _armPresence();
  }

  Future<String> _runAgent() async {
    final s = _settings!;
    final target = _messages.last;
    _afterthoughtUsedForTurn = false;
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
            if (i == lastImage &&
                tail[i].imageBase64 != null &&
                isUsableImageBase64(tail[i].imageBase64!))
              tail[i].toJson()
            else if (tail[i].imageBase64 == null)
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
          if (target.content.trim().isEmpty &&
              _messages.isNotEmpty &&
              identical(_messages.last, target)) {
            _messages.removeLast();
          }
        });
        unawaited(ChatStore.save(_messages));
        if (target.content.trim().isNotEmpty &&
            !_inCall &&
            _messages.contains(target)) {
          unawaited(_speak(target.content));
        }
        unawaited(_maybeSummarize(s));
        if (target.content.trim().isNotEmpty) _afterReplyOpportunities();
        if (_dayAnchorPending) {
          _dayAnchorPending = false;
          unawaited(_consider(InitiativeTrigger.dayAnchor));
        }
      }
    }
    return target.content.trim();
  }

  Future<({String text, List<Map<String, dynamic>> toolCalls})> _streamTurn(
    Settings s,
    List<Map<String, dynamic>> convo,
    Message target, {
    int? maxTokens,
    bool allowTools = true,
    bool reveal = true,
  }) async {
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
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (allowTools) 'tools': _toolSpecs,
        if (allowTools) 'tool_choice': 'auto',
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
            if (reveal && mounted) {
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
            if (reveal && mounted) setState(() => _activity = '正在查资料…');
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
    while (reveal && mounted && target.content.length < full.length) {
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
        // ComfyUI 的 CLIP 只认英文：中文原文发过去就是那张「水墨画」。
        final promptEn = await _englishImagePrompt(prompt);
        final negativeEn = await _englishImagePrompt((args['negative'] ?? '').toString());
        final patched = patchWorkflow(
          wf,
          prompt: promptEn,
          negative: negativeEn,
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
      await _store?.addFact(fact, importance: 4);
      await _reloadMemory();
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

  /// Typing or focusing the composer counts as presence: note it so the
  /// reopen and long-silence checks have a reference point. It never sends.
  void _noteInteraction() {
    _lastInteraction = DateTime.now();
  }

  /// Arms exactly one idle check [_idleMinutes] minutes from now.
  ///
  /// The delay is user-configurable (设置 → 主动开口 → 空闲多久主动找你),
  /// defaulting to 8 minutes and clamped to 3..120. Single-shot on purpose: on
  /// web nothing fires when the tab just sits there, so this is the only path
  /// that reaches [_consider] without a lifecycle event. It is re-armed after
  /// each send, each interaction and after saving settings, never on a
  /// repeating timer.
  void _armPresence() {
    if (_preview) return;
    _presenceTimer?.cancel();
    if (_settings?.proactiveEnabled != true) {
      _presenceArmedAt = null;
      _setNextCheckLabel(null);
      return;
    }
    final now = DateTime.now();
    final delay = _idleMinutes();
    _presenceArmedAt = now;
    _presenceTimer = Timer(Duration(minutes: delay), _onPresenceFire);
    debugPrint('[feiyu] idle check armed in ${delay}m');
    _setNextCheckLabel(now.add(Duration(minutes: delay)));
  }

  /// The user's requested idle delay, clamped to a sane 3..120 minutes.
  int _idleMinutes() {
    final raw = _settings?.proactiveIdleMinutes ?? 8;
    if (raw < 3) return 3;
    if (raw > 120) return 120;
    return raw;
  }

  void _onPresenceFire() {
    _presenceTimer = null;
    final armedAt = _presenceArmedAt;
    final last = _lastInteraction;
    debugPrint('[feiyu] presence fired');
    // The user was active after this check was armed: the chance is stale, so
    // replace it with a fresh single-shot check instead of speaking now.
    if (last != null && armedAt != null && last.isAfter(armedAt)) {
      _armPresence();
      return;
    }
    // Still idle: consider once, then stay disarmed. The next real interaction
    // re-arms a fresh check.
    _setNextCheckLabel(null);
    if (!mounted) return;
    unawaited(_consider(InitiativeTrigger.presence));
  }

  /// Quiet ambient pull of real headlines into [_inbox].
  ///
  /// It never calls a model, only the public JSON feeds: this is the free
  /// material the veto gate reads later. Single-shot and chained only after
  /// each run finishes, so runs can never pile up.
  Future<void> _bootHeartbeat() async {
    if (_preview) return;
    try {
      _inbox = await FeedInbox.load();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[feiyu] inbox load FAILED: $e');
    }
    if (!mounted) return;
    unawaited(_runHeartbeat());
  }

  Future<void> _runHeartbeat() async {
    if (_preview) return;
    var added = 0;
    try {
      final fresh = await fetchFeeds(httpGet: defaultJsonFetcher);
      added = await _inbox.addAll(fresh);
      await _inbox.prune();
      _heartbeatFailed = fresh.isEmpty;
    } catch (e) {
      _heartbeatFailed = true;
      debugPrint('[feiyu] heartbeat fetch failed: $e');
    }
    debugPrint('[feiyu] inbox +$added total=${_inbox.items.length}');
    if (mounted) setState(() {});
    if (!mounted || _preview) return;
    // Success: 90..180 minutes. Failure: back off to 180 so we never hammer.
    final delay = _heartbeatFailed
        ? const Duration(minutes: 180)
        : Duration(minutes: 90 + _rng.nextInt(91));
    _scheduleHeartbeat(delay);
  }

  void _scheduleHeartbeat(Duration delay) {
    if (_preview) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer(delay, () {
      _heartbeatTimer = null;
      unawaited(_runHeartbeat());
    });
    debugPrint('[feiyu] heartbeat next in ${delay.inMinutes}m');
  }

  void _setNextCheckLabel(DateTime? at) {
    final label = at == null
        ? null
        : '下次检查：约 ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}（presence）';
    if (!mounted) {
      _nextCheckLabel = label;
      return;
    }
    setState(() => _nextCheckLabel = label);
  }

  /// The user actually sent something: forgive past silence, mark the day as
  /// anchored and restart the long-silence clock.
  void _noteUserMessage() {
    final now = DateTime.now();
    _rollDay(now);
    _lastInteraction = now;
    _ignoredStreak = 0;
    _persistBudget();
    _ignoredTimer?.cancel();
    _ignoredTimer = null;
    if (!_preview && !_dayAnchorDone) _dayAnchorPending = true;
    _armLongSilence(now);
  }

  /// Rolls the per-day counters when the local date changes.
  void _rollDay(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    if (_day != null && _day == day) return;
    _day = day;
    _opportunitiesToday = 0;
    _proactiveToday = 0;
    _ignoredStreak = 0;
    _unsureToday = 0;
    _dayAnchorDone = false;
    _longSilenceDone = false;
    _afterthoughtUsedForTurn = false;
    _persistBudget();
  }

  /// Writes the in-memory counters through to [InitiativeBudget].
  ///
  /// Fire-and-forget: a failed write only costs the next launch its head start,
  /// and the in-memory values keep governing this session.
  void _persistBudget() {
    final InitiativeBudget budget = _budget ??= InitiativeBudget(
      day: DateTime.now(),
    );
    budget
      ..day = _day ?? budget.day
      ..sent = _proactiveToday
      ..opportunities = _opportunitiesToday
      ..ignoredStreak = _ignoredStreak
      ..unsure = _unsureToday
      ..lastAt = _lastProactiveAt;
    unawaited(budget.save());
  }

  /// A promise to come back later becomes one single-shot opportunity.
  void _schedulePendingThread(String text) {
    if (_preview || !promiseLike(text)) return;
    final now = DateTime.now();
    _pendingThreadDay = DateTime(now.year, now.month, now.day);
    _pendingThreadTimer?.cancel();
    _pendingThreadTimer = Timer(
      Duration(minutes: 35 + _rng.nextInt(41)),
      () {
        _pendingThreadTimer = null;
        final at = DateTime.now();
        final day = DateTime(at.year, at.month, at.day);
        if (_pendingThreadDay == null || _pendingThreadDay != day) return;
        unawaited(_consider(InitiativeTrigger.pendingThread));
      },
    );
  }

  /// At most one long-silence check per day, six hours after the last message.
  void _armLongSilence(DateTime now) {
    _longSilenceTimer?.cancel();
    if (_longSilenceDone) return;
    _longSilenceTimer = Timer(const Duration(hours: 6), () {
      _longSilenceTimer = null;
      if (!mounted) return;
      _rollDay(DateTime.now());
      if (_longSilenceDone) return;
      _longSilenceDone = true;
      unawaited(_consider(InitiativeTrigger.longSilence));
    });
  }

  /// A single small follow-up offer after she has already replied.
  void _afterReplyOpportunities() {
    if (_preview || _afterthoughtUsedForTurn) return;
    if (_input.text.trim().isNotEmpty) return;
    if (_rng.nextDouble() >= .30) return;
    _afterthoughtUsedForTurn = true;
    _afterthoughtTimer?.cancel();
    _afterthoughtTimer = Timer(
      Duration(minutes: 2 + _rng.nextInt(4)),
      () {
        _afterthoughtTimer = null;
        unawaited(_consider(InitiativeTrigger.afterthought));
      },
    );
  }

  String _sharePrompt() {
    final buffer = StringBuffer(
      '你现在有一个空档。手上有这些还没分享的发现，挑一条你觉得值得讲的，'
      '直接用 fetch_url 打开它对应的 url 取一次原文（不要另去找）：\n',
    );
    final items = _inbox.items.take(5).toList();
    if (items.isEmpty) {
      buffer.writeln('- （手头没有现成的，可去 https://www.v2ex.com/api/topics/hot.json 取一次）');
    } else {
      for (final item in items) {
        buffer.writeln('- ${item.title}（${item.source}）：${item.url}');
      }
    }
    buffer.writeln();
    buffer.writeln(
      '格式要求（严格遵守）：\n'
      '1. 一句话结论（这条观察是什么）\n'
      '2. 原文链接，必须来自 fetch_url 的真实返回，不许编造\n'
      '总长不超过 4 句。取不到合适内容、或链接你之前已经发过，就只回复 SILENCE。',
    );
    return buffer.toString();
  }

  static const String _chatNudge =
      '主人已经一段时间没说话了。用一句很短的话主动搭个话：可以接着刚才的话题，'
      '也可以随口分享一点自己的念头。不要问「你在吗」，不要客套，不要超过 30 字。';

  static const String _vetoNudge = '你要决定现在要不要主动找他。\n'
      '大多数时候可以说：你记得他的事、你们刚聊过、时间合适、或者你有具体想说的，都属于可以。\n'
      '只有下面情况才沉默：深夜他真的该睡了、他刚被拒绝/明显情绪不好、你确实没有任何新东西。\n'
      '能说话就说。宁可短，也别不说。\n'
      '只输出以下之一，不要解释：SILENT / SPEAK:CHAT / SPEAK:SHARE';

  /// The veto prompt, with any buffered headlines folded in.
  String _vetoPrompt() {
    final buffer = StringBuffer(_vetoNudge)..writeln();
    if (_inbox.unsharedCount > 0) {
      buffer.writeln(
        '你手上有 ${_inbox.unsharedCount} 条还没分享的发现（标题 + 来源）。'
        '有值得讲的就挑一条，用 SPEAK:SHARE；只想闲聊用 SPEAK:CHAT；确实没有就 SILENT。',
      );
      for (final item in _inbox.items.take(5)) {
        buffer.writeln('- ${item.title}（${item.source}）');
      }
    } else {
      buffer.writeln(
        '你手上现在没有新的发现，想主动找他只能闲聊，用 SPEAK:CHAT；不想说话用 SILENT。',
      );
    }
    return buffer.toString();
  }

  static final RegExp _urlPattern = RegExp(
    r'''https?://[^\s<>'")\]}，。；！？]+''',
    caseSensitive: false,
  );

  static List<String> _urlsIn(String text) => _urlPattern
      .allMatches(text)
      .map((m) => m.group(0)!.replaceAll(RegExp(r'[.,;!?]+$'), ''))
      .where((u) => u.isNotEmpty)
      .toList();

  void _startIgnoredCountdown() {
    final firedAt = DateTime.now();
    _ignoredTimer?.cancel();
    _ignoredTimer = Timer(const Duration(minutes: 10), () {
      if (!mounted) return;
      final last = _lastInteraction;
      if (last != null && last.isAfter(firedAt)) return;
      _ignoredStreak++;
      _persistBudget();
      debugPrint('[feiyu] no reply in 10m, ignored streak → $_ignoredStreak');
    });
  }

  /// An event asked to speak; policy and the model veto still stand in the way.
  ///
  /// Every call counts toward the per-day opportunity cap *before* the veto,
  /// so a broken provider cannot make her spin.
  Future<void> _consider(
    InitiativeTrigger trigger, {
    String reason = '',
  }) async {
    if (_preview) return;
    final s = _settings;
    if (s == null || !s.proactiveEnabled) return;
    if (!mounted || _busy || _messages.isEmpty) return;
    final now = DateTime.now();
    _rollDay(now);
    if (inQuietHours(now)) return;
    if (_proactiveToday >= 3 || _ignoredStreak >= 3) return;
    if (_opportunitiesToday >= 6) return;
    // The safety net that holds even when the veto says "go ahead": two
    // proactive messages can never be closer than [minProactiveGap], so a
    // stack of timers firing together still produces at most one message.
    if (!gapAllowsSpeak(_lastProactiveAt, now)) return;
    if (trigger == InitiativeTrigger.dayAnchor) _dayAnchorDone = true;
    if (trigger == InitiativeTrigger.longSilence) _longSilenceDone = true;

    _opportunitiesToday++;
    _persistBudget();
    final status = await _runInitiative(trigger, reason: reason);
    if (mounted) setState(() => _lastInitiativeStatus = status);
  }

  /// Shared veto → speak path. Returns a short human status string (without
  /// the leading clock for callers that add their own timestamp).
  Future<String> _runInitiative(
    InitiativeTrigger trigger, {
    String reason = '',
  }) async {
    final stamp = _stamp();
    // A manual run is an explicit "show me something now", so it never ends in
    // silence. With buffered headlines it still asks the model once (cheap) so
    // it can prefer a share; otherwise it just chats. Automatic opportunities
    // always pass through the (speak-biased) veto gate.
    InitiativeMode mode;
    bool unsure = false;
    if (trigger == InitiativeTrigger.manual) {
      if (_inbox.unsharedCount > 0) {
        final veto = await _veto(trigger, reason);
        unsure = veto == null;
        mode = veto == InitiativeMode.share
            ? InitiativeMode.share
            : InitiativeMode.chat;
      } else {
        mode = InitiativeMode.chat;
      }
    } else {
      final veto = await _veto(trigger, reason);
      unsure = veto == null;
      mode = veto ?? InitiativeMode.chat;
    }
    // When the gate could not answer we still prefer speaking, but only a
    // couple of times a day: a broken provider must not become a chatty one.
    if (unsure && !unsureAllowsSpeak(_unsureToday)) {
      return '$stamp · 网关没给出判断，今天兜底次数用完了';
    }
    if (mode == InitiativeMode.silent) {
      return '$stamp · 她决定先不说话（SILENT）';
    }
    if (!mounted || _busy) {
      return '$stamp · 她决定先不说话（SILENT）';
    }
    final s = _settings;
    if (mode == InitiativeMode.share && (s == null || !s.proactiveShareEnabled)) {
      mode = InitiativeMode.chat;
    }
    final outcome = await _speakUp(trigger, mode);
    if (unsure &&
        (outcome == 'sent-chat' || outcome == 'sent-share')) {
      _unsureToday++;
      _persistBudget();
    }
    return _initiativeStatusFrom(stamp, outcome, trigger);
  }

  String _initiativeStatusFrom(
    String stamp,
    String outcome, [
    InitiativeTrigger trigger = InitiativeTrigger.afterthought,
  ]) {
    if (outcome == 'sent-share') {
      return trigger == InitiativeTrigger.manual
          ? '$stamp · 手动测试已发出'
          : '$stamp · 分享已发出';
    }
    if (outcome == 'sent-chat') {
      return trigger == InitiativeTrigger.manual
          ? '$stamp · 手动测试已发出'
          : '$stamp · 她主动说了一句';
    }
    if (outcome == 'blocked') return '$stamp · 被否决：没有新链接';
    if (outcome.startsWith('failed:')) {
      var detail = outcome.substring(7).trim();
      if (detail.length > 60) detail = detail.substring(0, 60);
      return '$stamp · 失败：$detail';
    }
    return '$stamp · 她决定先不说话（SILENT）';
  }

  /// Runs one opportunity right now, on explicit user request from Settings.
  ///
  /// Bypasses quiet hours, daily caps and the ignored streak, but never the
  /// veto gate or the fresh-link rule.
  Future<String> _tryInitiativeNow() async {
    if (_busy) {
      const msg = '她正在回复，稍后再试';
      _lastInitiativeStatus = msg;
      return msg;
    }
    final s = _settings;
    if (s == null || s.model.trim().isEmpty || s.apiKey.trim().isEmpty) {
      const msg = '还没配好模型或 Key';
      _lastInitiativeStatus = msg;
      return msg;
    }
    if (!mounted || _messages.isEmpty) {
      final msg = '${_stamp()} · 还没有聊过，没法主动开口';
      _lastInitiativeStatus = msg;
      return msg;
    }
    _rollDay(DateTime.now());
    final status = await _runInitiative(InitiativeTrigger.manual, reason: 'manual');
    if (mounted) setState(() => _lastInitiativeStatus = status);
    return status;
  }

  String _stamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  /// Asks the model whether this opportunity is worth a message, and how.
  ///
  /// Returns `null` when the gate could not answer at all (timeout, network,
  /// junk reply). Callers treat that as "unknown" and may still speak, inside
  /// a much tighter budget. A reply that names no mode is a decision to stay
  /// silent, not a failure.
  Future<InitiativeMode?> _veto(
    InitiativeTrigger trigger, [
    String reason = '',
  ]) async {
    final s = _settings;
    if (s == null) return InitiativeMode.silent;
    final recent = _messages.where((m) => m.content.trim().isNotEmpty).toList();
    if (recent.isEmpty) return InitiativeMode.silent;
    final tail = recent.length > 8 ? recent.sublist(recent.length - 8) : recent;
    final last = _lastInteraction ?? _lastProactiveAt;
    final minutes =
        last == null ? 9999 : DateTime.now().difference(last).inMinutes;
    final context = tail
        .map((m) => '${m.role == 'user' ? '主人' : '我'}：${m.content}')
        .join('\n');
    final convo = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt(s)},
      {'role': 'user', 'content': '$context\n距上次说话：$minutes 分钟'},
      {'role': 'system', 'content': _vetoPrompt()},
    ];
    try {
      final target = Message('assistant', '');
      final result = await _streamTurn(
        s,
        convo,
        target,
        maxTokens: 40,
        allowTools: false,
        reveal: false,
      ).timeout(const Duration(seconds: 30));
      final mode = parseVetoReply(result.text);
      debugPrint(
        '[feiyu] initiative mode=${mode.name} trigger=${trigger.name} reason=$reason',
      );
      return mode;
    } catch (e) {
      // The gate is speak-biased on purpose ("能说话就说"). If we cannot get an
      // opinion at all (timeout / provider hiccup), fall through to chatting
      // instead of silently doing nothing. That is safe only because of the
      // independent ceilings: [_maxUnsurePerDay] for exactly this case,
      // [_minProactiveGap] between any two messages, and the daily caps.
      debugPrint('[feiyu] veto ${trigger.name} failed, defaulting to chat: $e');
      return null;
    }
  }

  Future<String> _speakUp(
    InitiativeTrigger trigger,
    InitiativeMode mode,
  ) async {
    final s = _settings;
    if (s == null) return 'failed:没有设置';
    final recent = _messages
        .where((m) => m.content.trim().isNotEmpty)
        .toList()
        .reversed
        .take(6)
        .toList()
        .reversed
        .map((m) => '${m.role == 'user' ? '主人' : '我'}：${m.content}')
        .join('\n');
    if (recent.isEmpty) return 'silent';

    final isShare = mode == InitiativeMode.share;
    try {
      setState(() => _busy = true);

      // 旧事：给她一颗很久没碰的星当话头，用不用由她决定。
      var nudge = isShare ? _sharePrompt() : _chatNudge;
      if (!isShare) {
        final hook = await _store?.hookLine() ?? '';
        if (hook.isNotEmpty) {
          nudge = '$nudge\n\n记忆里有一件旧事：$hook。'
              '如果这会儿接得上就顺口提一句，接不上就算了，别硬拉。';
        }
      }

      var said = await _runProactiveTurn(
        s,
        recent,
        nudge,
      );

      if (!mounted || said.isEmpty || isSilenceReply(said)) {
        if (mounted && said.isNotEmpty) {
          debugPrint('[feiyu] proactive ${trigger.name} chose SILENCE');
        }
        return 'silent';
      }

      if (isShare && !hasFreshLink(said, _sharedUrls.urls)) {
        // One more fetch with an explicit nudge, then give up quietly.
        said = await _runProactiveTurn(
          s,
          recent,
          '${_sharePrompt()}\n你刚想发的那条链接之前已经发过了，换一条。',
        );
        if (!mounted ||
            said.isEmpty ||
            isSilenceReply(said) ||
            !hasFreshLink(said, _sharedUrls.urls)) {
          debugPrint('[feiyu] share dropped: duplicate link');
          return 'blocked';
        }
      }

      final urls = isShare ? _urlsIn(said) : const <String>[];
      setState(() {
        _proactiveToday++;
        _lastProactiveAt = DateTime.now();
        _messages.add(Message('assistant', said));
      });
      _persistBudget();
      unawaited(ChatStore.save(_messages));
      _scrollToEnd();
      if (isShare) {
        // Remember the find as a footprint so 足迹 shows what she shared.
        final source =
            _inbox.items.isNotEmpty ? _inbox.items.first.source : '网页';
        unawaited(_sharedUrls.remember(urls));
        unawaited(_inbox.markShared(urls));
        final fp = footprintFromShare(
          source: source,
          text: said,
          at: DateTime.now(),
        );
        setState(() => _footprints = [fp, ..._footprints]);
        unawaited(FootprintStore.save(_footprints));
        debugPrint('[feiyu] share sent url=${urls.first}');
      }
      _startIgnoredCountdown();
      return isShare ? 'sent-share' : 'sent-chat';
    } catch (e) {
      // Proactive turns are best-effort.
      return 'failed:$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Runs one proactive generation, executing any tool calls it asks for.
  Future<String> _runProactiveTurn(
    Settings s,
    String recent,
    String nudge,
  ) async {
    final target = Message('assistant', '');
    final convo = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt(s)},
      {'role': 'user', 'content': recent},
      {'role': 'system', 'content': nudge},
    ];

    var said = '';
    for (var round = 0; round < 4; round++) {
      final result = await _streamTurn(s, convo, target);
      said = result.text.trim();
      if (result.toolCalls.isEmpty) break;
      convo.add({
        'role': 'assistant',
        'content': result.text,
        'tool_calls': result.toolCalls,
      });
      for (final call in result.toolCalls) {
        final fn = (call['function'] ?? const {}) as Map;
        final name = (fn['name'] ?? '') as String;
        final rawArgs = (fn['arguments'] ?? '{}') as String;
        final id = (call['id'] ?? '') as String;
        String output;
        try {
          final args = (jsonDecode(rawArgs.isEmpty ? '{}' : rawArgs) as Map)
              .cast<String, dynamic>();
          output = await _execTool(name, args);
        } catch (e) {
          output = '工具执行失败：$e';
        }
        convo.add({'role': 'tool', 'tool_call_id': id, 'content': output});
        if (mounted) setState(() => _activity = '');
      }
    }
    return said;
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
            {'role': 'user', 'content': factExtractionPrompt(recent)},
          ],
        }),
      );
      if (res.statusCode != 200) return;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final raw = ((j['choices'] as List).first['message'] as Map)['content'] as String? ?? '';
      final drafts = parseFactDrafts(raw).where((d) => d.text != '无').take(4).toList();
      if (drafts.isEmpty) return;
      await _store?.mergeFactDrafts(drafts, localOnly: looksSensitive(recent));
      await _reloadMemory();
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

  /// 开始一段新会话：先存档再清空，10 秒内可以撤销。
  ///
  /// 这里以前是一键硬删，误触一次整段对话就没了。现在旧对话写进
  /// `feiyu.history.archive`，并且提示条里能直接恢复。
  Future<void> _clear() async {
    if (_messages.isEmpty) {
      if (_error != null) setState(() => _error = null);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('开始新会话？'),
        content: const Text('当前这段对话会先存档，然后从空白开始。\n清空后 10 秒内可以撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('继续聊'),
          ),
          TextButton(
            key: const ValueKey('chat-clear-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('存档并清空'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final old = List<Message>.of(_messages);
    await ChatStore.archive(old);
    await ChatStore.save(const []);
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _error = null;
      _summarized = 0;
      _turnsSinceDigest = 0;
      _chatEpoch++;
    });
    unawaited(ChatStore.saveCursor(0));
    _scrollToEnd(animate: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已开始新会话，上一段存了 ${old.length} 条'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => unawaited(_restoreArchivedChat()),
        ),
      ),
    );
  }

  /// 把上一段被清空的对话找回来（提示条里的「撤销」）。
  Future<void> _restoreArchivedChat() async {
    final archived = await ChatStore.loadArchive();
    if (archived.isEmpty || !mounted) return;
    final merged = ChatStore.merge(archived, _messages);
    await ChatStore.save(merged);
    await ChatStore.saveCursor(merged.length);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(merged);
      // 存档里的内容之前已经整理过，别在下一句话时整段重抽。
      _summarized = merged.length;
      _chatEpoch++;
    });
    _scrollToEnd(animate: false);
  }

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

  Future<void> _speak(
    String text, {
    bool force = false,
    bool awaitCompletion = false,
  }) async {
    final s = _settings;
    if (s == null || (!force && !s.ttsEnabled) || text.trim().isEmpty) return;
    // Long essays get tiring to hear.
    final spoken = text.length > 220 ? '${text.substring(0, 220)}…' : text;

    if (s.ttsEngine == 'local') {
      try {
        final engine = _localTts ??= await LocalTtsImpl.create();
        if (await engine.ready) {
          final ok = await engine.speak(
            spoken,
            sid: s.ttsSid,
            speed: s.ttsSpeed,
            awaitCompletion: awaitCompletion,
          );
          if (!ok) debugPrint('[feiyu] local tts produced nothing');
          return;
        }
        if (!force) {
          debugPrint('[feiyu] local tts model missing');
          return;
        }
        // Call mode wants audio: fall through to the system engine.
      } catch (e) {
        debugPrint('[feiyu] local tts FAILED: $e');
        if (!force) return;
      }
    }

    try {
      await _tts.stop();
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.52);
      await _tts.setPitch(1.05);
      await _tts.awaitSpeakCompletion(awaitCompletion);
      await _tts.speak(spoken);
    } catch (e) {
      debugPrint('[feiyu] system tts FAILED: $e');
      // 有些手机根本没装中文语音包。Kokoro 只差一次下载，别让她哑掉。
      try {
        final engine = _localTts ??= await LocalTtsImpl.create();
        if (await engine.ready) {
          await engine.speak(
            spoken,
            sid: s.ttsSid,
            speed: s.ttsSpeed,
            awaitCompletion: awaitCompletion,
          );
        }
      } catch (e2) {
        debugPrint('[feiyu] local tts fallback FAILED: $e2');
      }
    }
  }

  /// A person does not send one wall of text. If she used `|||`, deliver each
  /// part as its own message with a small pause in between.
  Future<void> _splitIntoSentences(Message target) async {
    // 用户可能在回复途中「开始新会话」，这条消息已经不在列表里了。
    if (!_messages.contains(target)) return;
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
      if (!mounted || !_messages.contains(target)) return;
      setState(() => _messages.add(Message('assistant', parts[i])));
      _scrollToEnd();
    }
    if (mounted) unawaited(ChatStore.save(_messages));
  }

  /// The most recent picture the owner sent or that she produced.
  String? _lastImageBase64() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      final img = _messages[i].imageBase64;
      if (img != null && isUsableImageBase64(img)) return img;
    }
    return null;
  }

  // ---------------- memory layers ----------------

  Embedder _embedder(Settings s) =>
      Embedder(baseUrl: s.baseUrl, apiKey: s.apiKey, model: s.embeddingModel);

  /// 记忆落库后刷新常驻 prompt 片段（事实 + 今天的摘要 + 日结）。
  Future<void> _reloadMemory() async {
    final store = _store;
    if (store == null) return;
    try {
      final prompt = await store.factsPrompt();
      final digest = await store.recentDigest();
      final timeline = await store.timelinePrompt();
      if (!mounted) return;
      setState(() {
        _factsPrompt = prompt;
        _digest = digest;
        _timeline = timeline;
      });
    } catch (e) {
      debugPrint('[feiyu] memory reload FAILED: $e');
    }
  }

  /// 记忆的管家：调模型 + 算向量，都走当前设置。
  MemoryCurator? _curator(Settings? s) {
    final store = _store;
    if (store == null || s == null) return null;
    return MemoryCurator(
      store: store,
      chat: (prompt) => _plainChat(s, prompt),
      embed: (text) async => (await _embedder(s).embed(text)) ?? const <double>[],
    );
  }

  /// SD-Turbo 的文本编码器只认英文：中文提示词会被编码到训练分布之外，
  /// 出来的就是一张灰糊的「水墨画」。翻译一次，同一个描述不再重复花 token。
  late final ImagePromptTranslator _imageText =
      ImagePromptTranslator(translate: _translateImagePrompt);

  Future<String> _translateImagePrompt(String text) async {
    final s = _settings;
    if (s == null) return text;
    return _plainChat(
      s,
      '你是 Stable Diffusion 提示词翻译器。把下面的画面描述写成一句简短、具体的英文提示词：'
      '主体、场景、光线、风格写到就行，不超过 25 个词；'
      '不要解释、不要引号、只输出这一句英文。\n\n$text',
      maxTokens: 120,
    );
  }

  /// 英文直接放过；中文先翻译。翻译失败就退回原文（至少和以前一样）。
  Future<String> _englishImagePrompt(String text) => _imageText.english(text);

  /// 一次性、非流式的模型调用（抽记忆、结账、翻译提示词都用它）。
  ///
  /// 这些调用不需要「先想一段」：在推理型模型上，思考过程会把 max_tokens 吃光，
  /// `content` 返回空串（翻译提示词曾因此整段丢掉）。所以默认关掉推理，遇到不认
  /// 这个参数的网关再退回普通请求。
  Future<String> _plainChat(Settings s, String prompt, {int? maxTokens}) async {
    final base = s.baseUrl.endsWith('/') ? s.baseUrl.substring(0, s.baseUrl.length - 1) : s.baseUrl;

    Future<http.Response> send({required bool quiet}) => http
        .post(
          Uri.parse('$base/chat/completions'),
          headers: {'content-type': 'application/json', 'authorization': 'Bearer ${s.apiKey}'},
          body: jsonEncode({
            'model': s.model,
            'stream': false,
            if (maxTokens != null) 'max_tokens': maxTokens,
            if (quiet) 'reasoning_effort': 'none',
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(const Duration(seconds: 90));

    var res = await send(quiet: true);
    if (res.statusCode == 400) res = await send(quiet: false);
    if (res.statusCode != 200) {
      throw StateError('memory chat HTTP ${res.statusCode}');
    }
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final msg = ((j['choices'] as List).first as Map)['message'] as Map;
    return (msg['content'] as String? ?? '').trim();
  }

  /// 结账：把走完的日子折成日结，再往上折周/月。启动后跑一次，之后每天 23:10 一次。
  Future<void> _runMemoryMaintenance() async {
    // 先结账再清扫：清扫会把老情景打进冷宫，先扫的话它们就再也折不进日结了。
    final c = _curator(_settings);
    if (c != null) {
      try {
        final report = await c.runMaintenance();
        debugPrint('[feiyu] memory maintenance $report');
        if (report.didSomething) await _reloadMemory();
      } catch (e) {
        debugPrint('[feiyu] memory maintenance FAILED: $e');
      }
    }
    final store = _store;
    if (store != null) {
      try {
        // 旧星褪色、剪掉废边、把太旧的情景放进冷宫（不删）。
        final swept = await store.nightlySweep();
        if (swept > 0) debugPrint('[feiyu] nightly sweep touched $swept');
      } catch (e) {
        debugPrint('[feiyu] nightly sweep FAILED: $e');
      }
    }
  }

  /// 设置和记忆库都就绪后再跑启动维护：谁先回来都行，只跑一次。
  /// 以前是记忆库一打开就跑，设置还没读回来时 `_curator` 为 null，维护就静默跳过了。
  void _bootMemoryOnce() {
    if (_memoryBooted || _store == null || _settings == null) return;
    _memoryBooted = true;
    unawaited(_runMemoryMaintenance());
    _scheduleMemoryMaintenance();
  }

  void _scheduleMemoryMaintenance() {
    _memoryTimer?.cancel();
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, 23, 10);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    _memoryTimer = Timer(next.difference(now), () async {
      await _runMemoryMaintenance();
      _scheduleMemoryMaintenance();
    });
  }

  /// Compress the backlog into episodes + a day card source when it grows too long.
  Future<void> _maybeSummarize(Settings s) async {
    if (!s.memoryEnabled) return;
    if (_summarizing) return;
    final pending = _messages.length - _summarized;
    if (pending < 20) return;
    final end = _messages.length - 4;
    if (end <= _summarized) return;
    // 一次只喂模型一小段：积压再长也不会把上下文撑爆；失败了下一轮只重试这一段。
    const chunk = 40;
    var stop = _summarized + chunk < end ? _summarized + chunk : end;
    // 长文/粘贴的聊天记录再把这一段压短，别让一次抽取就超上下文。
    var chars = 0;
    for (var i = _summarized; i < stop; i++) {
      chars += _messages[i].content.length;
      if (chars > 6000 && i > _summarized) {
        stop = i;
        break;
      }
    }
    final slice = _messages.sublist(_summarized, stop);
    if (slice.isEmpty) return;
    final turns = slice
        .where((m) => m.content.trim().isNotEmpty)
        .map((m) => TranscriptTurn(fromUser: m.role == 'user', text: m.content))
        .toList();
    if (turns.isEmpty) {
      // 这一段全是空的（例如只剩图片占位），没什么可抽的，直接跨过去。
      _summarized = stop;
      unawaited(ChatStore.saveCursor(stop));
      return;
    }

    final curator = _curator(s);
    if (curator == null) return;
    // 记忆要锚在这段对话真正发生的时间上。重启后补抽的积压可能已经是几天前，
    // 用 DateTime.now() 会把它们全搬到今天，时间线就乱了。
    final anchor = slice.last.at;
    final epoch = _chatEpoch;
    _summarizing = true;
    try {
      final sensitive = s.privacyLocalOnly && looksSensitive(slice.map((m) => m.content).join('\n'));
      final added = await curator.extractEpisodes(turns, at: anchor, localOnly: sensitive);
      if (added == null) {
        // 模型/网络失败。游标不动，下一轮重试同一段，不能当成「没东西可记」跳过。
        debugPrint('[feiyu] summarize failed; kept cursor at $_summarized');
        return;
      }
      if (epoch != _chatEpoch) {
        // 抽的这段时间里用户开了新会话，这段结果已经不属于当前对话了。
        return;
      }
      _summarized = stop;
      unawaited(ChatStore.saveCursor(_summarized));
      if (added.isNotEmpty) {
        debugPrint('[feiyu] extracted ${added.length} episodes${sensitive ? ' (local only)' : ''}');
        await _reloadMemory();
      }
      if (!sensitive) {
        // 把这条边挂到刚写下的情景上，图扩展（_graphBoost）才有种子可查。
        final stars = await curator.extractGraph(
          turns,
          at: anchor,
          episodeId: added.isEmpty ? null : added.last,
        );
        if (stars > 0) debugPrint('[feiyu] graph +$stars entities');
      }
    } catch (e) {
      debugPrint('[feiyu] summarize FAILED: $e');
    } finally {
      _summarizing = false;
    }
  }

  Future<String> _recall(String query) async {
    final s = _settings;
    final store = _store;
    if (s == null || store == null) return '还没有设置，无法检索';
    final vector = await _embedQuery(s, query);
    final hits = await store.search(vector: vector, keyword: query, k: 3);
    if (hits.isEmpty) return '没有找到相关的旧记录';
    String day(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    return '找到这些旧记录：\n${hits.map((e) => '【${day(e.at)}】${e.body}').join('\n\n')}';
  }

  /// 检索向量的短期缓存：网关一次 embedding 要 150–570ms，同一句话反复问很常见。
  ///
  /// 只缓存最近 [vecCacheMax] 条，命中后挪到队尾（LRU）。查询文本没变，向量就不会变。
  final Map<String, List<double>> _vecCache = <String, List<double>>{};
  static const int vecCacheMax = 48;

  Future<List<double>> _embedQuery(Settings s, String text) async {
    final key = text.trim().toLowerCase();
    final hit = _vecCache.remove(key);
    if (hit != null) {
      _vecCache[key] = hit;
      return hit;
    }
    final v = await _embedder(s).embed(text) ?? const <double>[];
    if (v.isNotEmpty) {
      _vecCache[key] = v;
      if (_vecCache.length > vecCacheMax) _vecCache.remove(_vecCache.keys.first);
    }
    return v;
  }

  // ---------------- footprints ----------------

  Future<void> _openComfy() async {
    final s = _settings;
    if (s == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ComfyPage(
        baseUrl: s.comfyUrl,
        workflowJson: s.comfyWorkflow,
        onEditConfig: _comfyConfigAfterSettings,
        onTranslatePrompt: _englishImagePrompt,
        onUseAsAvatar: (Uint8List bytes) async {
          s.avatar = base64Encode(bytes);
          await s.save();
          if (!mounted) return;
          setState(() => _settings = s);
        },
      ),
    ));
    unawaited(_checkComfyState());
  }

  /// Settings → 「ComfyUI」, then hand the freshly saved values back to the
  /// drawing page (which would otherwise keep the old workflow).
  Future<ComfyConfig?> _comfyConfigAfterSettings() async {
    await _openSettings(focusComfy: true);
    if (!mounted) return null;
    final s = _settings;
    if (s == null) return null;
    return ComfyConfig(baseUrl: s.comfyUrl, workflowJson: s.comfyWorkflow);
  }

  /// Keep the little dot on the draw button honest.
  Future<void> _checkComfyState() async {
    final s = _settings;
    if (s == null) return;
    final bool online = await ComfyClient.resolved(s.comfyUrl, web: kIsWeb).ping();
    if (!mounted) return;
    setState(() => _comfyOnline = online);
  }

  Future<void> _openFootprints() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FootprintsPage(
        items: _footprints,
        avatarBase64: _settings?.avatar,
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
          avatarBase64: _settings?.avatar,
          onFootprints: _openFootprints,
          onComfy: _openComfy,
          comfyOnline: _comfyOnline,
          onNewChat: () => unawaited(_clear()),
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
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _messages.isEmpty
                              ? _emptyState()
                              : _messageList(),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 8,
                          child: ExcludeSemantics(
                            excluding: !_showJump,
                            child: IgnorePointer(
                              ignoring: !_showJump,
                              child: AnimatedOpacity(
                                opacity: _showJump ? 1 : 0,
                                duration: AppDurations.base,
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Material(
                                    color: AppPalette.surfaceHi,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      tooltip: '回到底部',
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 40,
                                            height: 40,
                                          ),
                                      onPressed: _scrollToEnd,
                                      icon: const Icon(
                                        Icons.arrow_downward,
                                        size: 18,
                                        color: AppPalette.text1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_pendingImage != null) _pendingImageBar(),
                  if (_listening) _listeningBar(),
                  if (_callPhase != CallPhase.off)
                    CallBanner(phase: _callPhase, message: _callErrorText),
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
      avatarBase64: _settings?.avatar,
    );
  }

  Widget _messageList() {
    return MessageList(
      messages: _messages,
      busy: _busy,
      waitingFirstToken: _waitingFirstToken,
      onOpenImage: _openImage,
      controller: _scroll,
      avatarBase64: _settings?.avatar,
      userAvatarBase64: _settings?.userAvatar,
    );
  }

  void _openImage(String b64) {
    showImageViewer(context, base64Decode(b64));
  }

  Widget _pendingImageBar() {
    return PendingImageBar(
      bytes: base64Decode(_pendingImage!),
      onRemove: () => setState(() => _pendingImage = null),
    );
  }

  Widget _listeningBar() {
    return ListeningBar(
      hint: _voiceHint.isEmpty ? '正在听…' : _voiceHint,
    );
  }

  Widget _composer() {
    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus) _noteInteraction();
      },
      child: Composer(
        controller: _input,
        busy: _busy,
        listening: _listening,
        onImage: _imageSheet,
        onMic: _toggleVoice,
        onSend: _send,
        onStop: _stop,
        onSubmitted: (_) => _send(),
        hint: _listening ? '正在听…' : '和大肥鱼说点什么…',
        inCall: _inCall,
        onCall: _enterCall,
        onHangup: _hangup,
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final Settings initial;
  final MemoryStore? memory;
  final Future<void> Function()? onMemoryChanged;
  final GalaxyAsk? onTellAbout;
  final Future<String> Function()? onMemoryNow;
  final Future<void> Function()? onRestoreChat;
  final Future<String> Function()? onTryInitiative;
  final String? initialInitiativeStatus;
  final String? initialNextCheck;
  final int inboxCount;

  /// Opened from the drawing page: jump straight to the ComfyUI card instead
  /// of dropping the user at the top of a long settings list.
  final bool focusComfy;

  const SettingsPage({
    super.key,
    required this.initial,
    required this.memory,
    this.onMemoryChanged,
    this.onTellAbout,
    this.onMemoryNow,
    this.onRestoreChat,
    this.onTryInitiative,
    this.initialInitiativeStatus,
    this.initialNextCheck,
    this.inboxCount = 0,
    this.focusComfy = false,
  });
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ScrollController _scrollCtl = ScrollController();
  final GlobalKey _comfySectionKey = GlobalKey();
  late final TextEditingController _base;
  late final TextEditingController _key;
  late final TextEditingController _model;
  late final TextEditingController _persona;
  late bool _memoryEnabled;
  late bool _privacyLocalOnly;
  List<Fact> _facts = const [];
  int _stars = 0;
  String? _exportHint;
  String? _memoryNowHint;
  bool _memoryNowBusy = false;
  bool _restoringChat = false;
  late bool _proactiveEnabled;
  late bool _proactiveShareEnabled;
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
  bool _comfyStarting = false;
  bool _downloadingTts = false;
  double _ttsProgress = 0;
  bool _asrModelReady = false;
  bool _downloadingAsr = false;
  double _asrProgress = 0;
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
  String? _initiativeStatus;
  bool _tryingInitiative = false;
  String? _avatar;
  String? _avatarError;
  String? _userAvatar;
  String? _userAvatarError;
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
    _privacyLocalOnly = widget.initial.privacyLocalOnly;
    _facts = const [];
    unawaited(_loadFacts());
    _proactiveEnabled = widget.initial.proactiveEnabled;
    _proactiveShareEnabled = widget.initial.proactiveShareEnabled;
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
    if (!kIsWeb) {
      LocalAsrImpl.create(kind: widget.initial.asrLocalModel).then((e) => e.ready).then((ok) {
        if (mounted) setState(() => _asrModelReady = ok);
      }).catchError((Object _) {});
    }
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
    _initiativeStatus = widget.initialInitiativeStatus;
    _avatar = widget.initial.avatar;
    _userAvatar = widget.initial.userAvatar;
    if (widget.initial.apiKey.trim().isNotEmpty) _loadModels();
    if (widget.focusComfy) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToComfy());
    }
  }

  void _scrollToComfy() {
    final BuildContext? ctx = _comfySectionKey.currentContext;
    if (ctx == null || !mounted) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: .02,
    );
  }

  @override
  void dispose() {
    _scrollCtl.dispose();
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
    // On web the page is on 127.0.0.1:8090, so a direct 8188 call is blocked
    // by CORS; go through the local server's /comfy proxy instead.
    final client = ComfyClient.resolved(url, web: kIsWeb);
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

  /// Web only: ask server.mjs to launch the ComfyUI supervisor, then wait for
  /// it to answer and report through the normal "测试连接" notice.
  Future<void> _startComfyFromSettings() async {
    setState(() {
      _comfyStarting = true;
      _comfyStatus = '正在启动 ComfyUI…（首次启动要加载模型，约 1 分钟）';
    });
    final String? err = await ComfyEngine.start();
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _comfyStarting = false;
        _comfyStatus = err;
      });
      return;
    }
    final url = _comfyUrl.text.trim().isEmpty ? 'http://192.168.1.10:8188' : _comfyUrl.text.trim();
    final client = ComfyClient.resolved(url, web: kIsWeb);
    for (int i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      if (await client.ping()) break;
      if (!mounted) return;
      setState(() => _comfyStatus = '正在启动 ComfyUI… ${(i + 1) * 3}s');
    }
    if (!mounted) return;
    setState(() => _comfyStarting = false);
    await _testComfy();
  }

  Future<void> _downloadTts() async {
    setState(() {
      _downloadingTts = true;
      _ttsProgress = 0;
    });
    try {
      final engine = await LocalTtsImpl.create();
      await engine.download(onProgress: (p) {
        if (mounted) setState(() => _ttsProgress = p);
      });
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

  /// One-time download of the on-device recogniser picked in [ _asrLocalModel ].
  Future<void> _downloadAsr() async {
    if (_downloadingAsr) return;
    final engine = await LocalAsrImpl.create(kind: _asrLocalModel);
    setState(() {
      _downloadingAsr = true;
      _asrProgress = 0;
    });
    try {
      await engine.download(onProgress: (p) {
        if (mounted) setState(() => _asrProgress = p);
      });
      final ok = await engine.ready;
      if (mounted) setState(() => _asrModelReady = ok);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('下载失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _downloadingAsr = false);
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
      if (!mounted) return;
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final ids = (j['data'] as List).map((e) => (e as Map)['id'].toString()).toList()..sort();
      setState(() {
        _models = ids;
        _loadingModels = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingModels = false;
        _modelError = '$e';
      });
    }
  }

  Settings _collect() {
    return Settings(
      baseUrl: _base.text.trim(),
      apiKey: _key.text.trim(),
      model: _model.text.trim(),
      persona: _persona.text,
      avatar: _avatar,
      userAvatar: _userAvatar,
      memoryEnabled: _memoryEnabled,
      privacyLocalOnly: _privacyLocalOnly,
      proactiveEnabled: _proactiveEnabled,
      proactiveIdleMinutes: _proactiveIdleMinutes,
      proactiveShareEnabled: _proactiveShareEnabled,
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
    );
  }

  void _save() {
    Navigator.of(context).pop(_collect());
  }

  Future<void> _tryInitiative() async {
    final cb = widget.onTryInitiative;
    if (cb == null || _tryingInitiative) return;
    setState(() => _tryingInitiative = true);
    try {
      final result = await cb();
      if (!mounted) return;
      setState(() => _initiativeStatus = result);
    } finally {
      if (mounted) setState(() => _tryingInitiative = false);
    }
  }

  /// Persists the current form without leaving the page — used by controls
  /// that should take effect immediately (e.g. picking an avatar).
  Future<void> _persist() async {
    await _collect().save();
  }

  Future<void> _pickAvatar() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        imageQuality: 80,
      );
      if (!mounted) return;
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 700 * 1024) {
        setState(() => _avatarError = '头像太大，换一张小一点的');
        return;
      }
      setState(() {
        _avatar = base64Encode(bytes);
        _avatarError = null;
      });
      await _persist();
    } catch (e) {
      if (!mounted) return;
      setState(() => _avatarError = '选图失败：$e');
    }
  }

  Future<void> _resetAvatar() async {
    if (_avatar == null) return;
    setState(() {
      _avatar = null;
      _avatarError = null;
    });
    await _persist();
  }

  Future<void> _pickUserAvatar() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        imageQuality: 80,
      );
      if (!mounted) return;
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 700 * 1024) {
        setState(() => _userAvatarError = '头像太大，换一张小一点的');
        return;
      }
      setState(() {
        _userAvatar = base64Encode(bytes);
        _userAvatarError = null;
      });
      await _persist();
    } catch (e) {
      if (!mounted) return;
      setState(() => _userAvatarError = '选图失败：$e');
    }
  }

  Future<void> _resetUserAvatar() async {
    if (_userAvatar == null) return;
    setState(() {
      _userAvatar = null;
      _userAvatarError = null;
    });
    await _persist();
  }

  Future<void> _loadFacts() async {
    final store = widget.memory;
    if (store == null) return;
    try {
      final facts = await store.facts();
      final stars = await store.entityCount();
      if (!mounted) return;
      setState(() {
        _facts = facts;
        _stars = stars;
      });
    } catch (e) {
      debugPrint('[feiyu] load facts FAILED: $e');
    }
  }

  /// 把整库导成一个 JSON 文件，让用户自己留着。
  Future<void> _exportMemory() async {
    final store = widget.memory;
    if (store == null) return;
    try {
      final snapshot = await store.exportSnapshot();
      // 聊天记录不在记忆库（drift）里，但「留底」必须连对话一起走：
      // 之前的导出只有星图/日记，用户拿到的备份缺了最核心的那部分。
      final chat = await ChatStore.load();
      snapshot['chat'] = chat.map((m) => m.toStore()).toList();
      final archived = await ChatStore.loadArchive();
      if (archived.isNotEmpty) {
        snapshot['chatArchive'] = archived.map((m) => m.toStore()).toList();
      }
      snapshot['chatCount'] = chat.length;
      final json = const JsonEncoder.withIndent('  ').convert(snapshot);
      final path = await saveMemoryExport(json);
      if (!mounted) return;
      setState(() => _exportHint = path == null ? '导出失败' : '已导出：$path');
    } catch (e) {
      if (!mounted) return;
      setState(() => _exportHint = '导出失败：$e');
    }
  }

  /// 把「上次清空」留下的存档合并回当前对话（撤销提示条 10 秒后就摸不到了）。
  Future<void> _restoreChat() async {
    final fn = widget.onRestoreChat;
    if (fn == null || _restoringChat) return;
    setState(() => _restoringChat = true);
    try {
      final archived = await ChatStore.loadArchive();
      if (archived.isEmpty) {
        if (!mounted) return;
        setState(() => _exportHint = '没有可恢复的对话存档');
        return;
      }
      await fn();
      if (!mounted) return;
      setState(() => _exportHint = '已合并回当前对话（${archived.length} 条）');
    } catch (e) {
      if (!mounted) return;
      setState(() => _exportHint = '恢复失败：$e');
    } finally {
      if (mounted) setState(() => _restoringChat = false);
    }
  }

  /// 手动跑一次整理，让用户不用等攒够消息就能看到星。
  Future<void> _runMemoryNow() async {
    final fn = widget.onMemoryNow;
    if (fn == null || _memoryNowBusy) return;
    setState(() {
      _memoryNowBusy = true;
      _memoryNowHint = '正在整理…';
    });
    final text = await fn();
    if (!mounted) return;
    setState(() {
      _memoryNowBusy = false;
      _memoryNowHint = text;
    });
    await _loadFacts();
  }

  /// 清空整库。这是不可逆操作，所以先问一遍。
  Future<void> _wipeMemory() async {
    final store = widget.memory;
    if (store == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空全部记忆？'),
        content: const Text('星图、日记、事实全部删掉，不能恢复。要留底就先导出。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('算了')),
          TextButton(
            key: const ValueKey('settings-wipe-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await store.wipe();
      await widget.onMemoryChanged?.call();
      await _loadFacts();
      if (!mounted) return;
      setState(() => _exportHint = '记忆已清空');
    } catch (e) {
      if (!mounted) return;
      setState(() => _exportHint = '清空失败：$e');
    }
  }

  Future<void> _openGalaxy() async {
    final store = widget.memory;
    if (store == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GalaxyPage(store: store, ask: widget.onTellAbout),
      ),
    );
    if (!mounted) return;
    await _loadFacts();
  }

  Future<void> _openHealth() async {
    final store = widget.memory;
    if (store == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => MemoryHealthPage(store: store)),
    );
    if (!mounted) return;
    await _loadFacts();
  }

  Future<String?> _promptFact({String initial = ''}) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial.isEmpty ? '添加一条记忆' : '编辑这条记忆'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '比如：你最喜欢雨天'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isEmpty) return;
              Navigator.of(ctx).pop(t);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  /// One remembered fact as a compact card; two of them fit side by side.
  Widget _factCard(int i) {
    final fact = _facts[i];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(AppRadii.m),
        border: Border.all(color: AppPalette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              fact.content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppType.bodySmall.copyWith(color: AppPalette.text2),
            ),
          ),
          const SizedBox(width: 2),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _FactAction(
                icon: Icons.edit_outlined,
                tooltip: '编辑这条记忆',
                onPressed: () => _editFact(i),
              ),
              _FactAction(
                icon: Icons.delete_outline,
                tooltip: '删除这条记忆',
                onPressed: () => _deleteFact(i),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editFact(int index) async {
    if (index < 0 || index >= _facts.length) return;
    final target = _facts[index];
    final result = await _promptFact(initial: target.content);
    if (!mounted || result == null || result.isEmpty) return;
    await widget.memory?.updateFactText(target.id, result);
    await widget.onMemoryChanged?.call();
    await _loadFacts();
  }

  Future<void> _addFact() async {
    final result = await _promptFact();
    if (!mounted || result == null || result.isEmpty) return;
    await widget.memory?.addFact(result, importance: 4);
    await widget.onMemoryChanged?.call();
    await _loadFacts();
  }

  Future<void> _deleteFact(int index) async {
    if (index < 0 || index >= _facts.length) return;
    final id = _facts[index].id;
    setState(() {
      final next = List<Fact>.of(_facts)..removeAt(index);
      _facts = next;
    });
    await widget.memory?.deleteFact(id);
    await widget.onMemoryChanged?.call();
    await _loadFacts();
  }

  @override
  Widget build(BuildContext context) {
    // Back (app-bar arrow or system gesture) must persist too, otherwise a
    // toggled switch is silently discarded because the route pops with null.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _save();
      },
      child: Scaffold(
      backgroundColor: AppPalette.ink,
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: _save, child: const Text('保存')),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            controller: _scrollCtl,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          SectionCard(
            key: const ValueKey('settings-section-model'),
            title: '模型',
            children: <Widget>[
              SettingsRow(
                label: '厂商',
                child: DropdownButtonFormField<String>(
                  initialValue: _provider,
                  isExpanded: true,
                  items: kProviders
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text('${p.name}${p.note.isEmpty ? '' : '  ·  ${p.note}'}',
                                overflow: TextOverflow.ellipsis, style: AppType.bodySmall),
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
              ),
              const SizedBox(height: 14),
              SettingsRow(
                label: 'Base URL',
                description: 'OpenAI 兼容，不带 /chat/completions',
                child: TextField(controller: _base, decoration: const InputDecoration(hintText: 'https://…/v1')),
              ),
              const SizedBox(height: 14),
              SettingsRow(
                label: 'API Key',
                child: TextField(
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
              ),
              const SizedBox(height: 14),
              if (_modelError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InlineNotice(tone: NoticeTone.danger, message: '拉取模型失败：$_modelError'),
                ),
              Builder(builder: (context) {
                final preset = providerById(_provider);
                final options = _models.isNotEmpty ? _models : preset.models;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SettingsRow(
                      label: '模型',
                      child: DropdownButtonFormField<String>(
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
                                  child: Text(id, overflow: TextOverflow.ellipsis, style: AppType.bodySmall),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _model.text = v);
                        },
                      ),
                    ),
                    if (_models.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Pill(label: '已拉取 ${_models.length} 个模型', tone: PillTone.success),
                      ),
                  ],
                );
              }),
              const SizedBox(height: 14),
              SettingsRow(
                label: '手动输入模型',
                child: TextField(
                  controller: _model,
                  decoration: const InputDecoration(hintText: '也可以手填模型名', isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            key: const ValueKey('settings-section-avatar'),
            title: '头像',
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _AvatarSettingsBlock(
                      title: '大肥鱼',
                      subtitle: '聊天和足迹里都会用它。',
                      imageBase64: _avatar,
                      error: _avatarError,
                      onPick: _pickAvatar,
                      onReset: _avatar == null ? null : _resetAvatar,
                      onDismissError: () => setState(() => _avatarError = null),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.l),
                  Expanded(
                    child: _AvatarSettingsBlock(
                      title: '你',
                      subtitle: '显示在你的每条消息旁边。',
                      imageBase64: _userAvatar,
                      error: _userAvatarError,
                      onPick: _pickUserAvatar,
                      onReset: _userAvatar == null ? null : _resetUserAvatar,
                      onDismissError: () =>
                          setState(() => _userAvatarError = null),
                      pickKey: const ValueKey('settings-avatar-self'),
                      useNeutralFallback: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            key: const ValueKey('settings-section-persona'),
            title: '人设',
            children: <Widget>[
              SettingsRow(
                label: '人设（system prompt）',
                description: '她说话的方式，可随时改写',
                child: TextField(
                  key: const ValueKey('settings-persona-field'),
                  controller: _persona,
                  minLines: 5,
                  maxLines: 12,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  TextButton(
                    onPressed: () => setState(() => _persona.text = kPresetPersona),
                    child: const Text('恢复默认人设'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '保存后生效',
                    style: AppType.caption.copyWith(color: AppPalette.text3),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            key: const ValueKey('settings-section-voice'),
            title: '语音',
            children: <Widget>[
              const SectionHeader(label: '语音朗读'),
              const SizedBox(height: 14),
              _SettingsSwitch(
                title: '语音朗读',
                subtitle: '回答完念出来（前三句左右）',
                value: _ttsEnabled,
                onChanged: (v) => setState(() => _ttsEnabled = v),
              ),
              if (_ttsEnabled) ...[
                const SizedBox(height: 14),
                SettingsRow(
                  label: '发音引擎',
                  description: '系统语音不用任何 Key；手机没装中文语音包就选本机 Kokoro',
                  child: DropdownButtonFormField<String>(
                    initialValue: _ttsEngine,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'system', child: Text('系统语音（免费、机械）', style: AppType.bodySmall)),
                      DropdownMenuItem(value: 'local', child: Text('本机 Kokoro（自然、离线）', style: AppType.bodySmall)),
                    ],
                    onChanged: (v) => setState(() => _ttsEngine = v ?? 'system'),
                  ),
                ),
                if (_ttsEngine == 'local') ...[
                  const SizedBox(height: 12),
                  SettingsRow(
                    label: '音色',
                    child: DropdownButtonFormField<int>(
                      initialValue: _ttsSid,
                      isExpanded: true,
                      items: LocalTtsImpl.voices.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value, style: AppType.bodySmall),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _ttsSid = v ?? 47),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('语速：', style: AppType.caption.copyWith(color: AppPalette.text3)),
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
                      Text(_ttsSpeed.toStringAsFixed(2), style: AppType.caption.copyWith(color: AppPalette.text2)),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _downloadingTts ? null : _downloadTts,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(_ttsModelReady ? '模型已就绪（点击重新下载）' : '下载语音模型（约 147 MB）'),
                    ),
                  ),
                  if (_downloadingTts) ...[
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: _ttsProgress),
                    const SizedBox(height: 4),
                    Text('${(_ttsProgress * 100).round()}%', style: AppType.caption.copyWith(color: AppPalette.text2)),
                  ],
                ],
              ],
              const SizedBox(height: 14),
              const SectionHeader(label: '语音识别'),
              const SizedBox(height: 14),
              SettingsRow(
                label: '语音识别服务',
                description: '「本机离线」不用 Key，第一次用下载一次模型就行',
                child: DropdownButtonFormField<String>(
                  initialValue: _asrPreset,
                  isExpanded: true,
                  items: kAsrPresets
                      .where((p) => !kIsWeb || p.id != 'local')
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name, style: AppType.bodySmall),
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
              ),
              if (_asrPreset == 'local') ...[
                const SizedBox(height: 12),
                SettingsRow(
                  label: '离线模型',
                  child: DropdownButtonFormField<String>(
                    initialValue: _asrLocalModel,
                    isExpanded: true,
                    items: LocalAsrImpl.models.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value, style: AppType.bodySmall),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _asrLocalModel = v ?? 'dolphin');
                      LocalAsrImpl.create(kind: _asrLocalModel).then((e) => e.ready).then((ok) {
                        if (mounted) setState(() => _asrModelReady = ok);
                      }).catchError((Object _) {});
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _downloadingAsr ? null : _downloadAsr,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(
                      _asrModelReady ? '模型已就绪（点击重新下载）' : '下载离线识别模型（免费）',
                    ),
                  ),
                ),
                if (_downloadingAsr) ...[
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: _asrProgress),
                  const SizedBox(height: 4),
                  Text('${(_asrProgress * 100).round()}%', style: AppType.caption.copyWith(color: AppPalette.text2)),
                ],
              ],
              if (_asrPreset != 'same' && _asrPreset != 'local') ...[
                const SizedBox(height: 12),
                SettingsRow(
                  label: 'Base URL',
                  child: TextField(
                    controller: _asrBase,
                    decoration: const InputDecoration(hintText: 'Base URL，例如 https://api.siliconflow.cn/v1', isDense: true),
                  ),
                ),
                const SizedBox(height: 12),
                SettingsRow(
                  label: 'API Key',
                  child: TextField(
                    controller: _asrKey,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '语音服务 API Key', isDense: true),
                  ),
                ),
              ],
              if (_asrPreset != 'local') ...[
                const SizedBox(height: 12),
                SettingsRow(
                  label: '转写模型',
                  child: TextField(
                    controller: _asr,
                    decoration: const InputDecoration(hintText: '转写模型，例如 FunAudioLLM/SenseVoiceSmall', isDense: true),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const SectionHeader(label: '看图模型'),
              const SizedBox(height: 14),
              _SettingsSwitch(
                title: '发图时切到看图模型',
                subtitle: '聊天模型不支持看图时，带图的这一条自动走另一个模型；其余消息仍用原模型',
                value: _visionEnabled,
                onChanged: (v) => setState(() => _visionEnabled = v),
              ),
              if (_visionEnabled) ...[
                const SizedBox(height: 14),
                SettingsRow(
                  label: '厂商',
                  child: DropdownButtonFormField<String>(
                    initialValue: _visionProvider,
                    isExpanded: true,
                    items: kProviders
                        .where((p) => p.id != 'custom')
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name, style: AppType.bodySmall),
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
                ),
                const SizedBox(height: 12),
                SettingsRow(
                  label: 'Base URL',
                  child: TextField(
                    controller: _visionBase,
                    decoration: const InputDecoration(hintText: 'Base URL', isDense: true),
                  ),
                ),
                const SizedBox(height: 12),
                SettingsRow(
                  label: 'API Key',
                  child: TextField(
                    controller: _visionKey,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '看图服务 API Key（留空则用聊天厂商的 Key）', isDense: true),
                  ),
                ),
                const SizedBox(height: 12),
                SettingsRow(
                  label: '看图模型',
                  child: TextField(
                    controller: _visionModel,
                    decoration: const InputDecoration(hintText: '看图模型，例如 qwen-vl-max / glm-4.5 / kimi-k3', isDense: true),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            key: const ValueKey('settings-section-memory'),
            title: '记忆与会话',
            children: <Widget>[
              _SettingsSwitch(
                title: '自动记忆',
                subtitle: '每几轮抽取关于你的长期事实，存在本机',
                value: _memoryEnabled,
                onChanged: (v) => setState(() => _memoryEnabled = v),
              ),
              const SizedBox(height: 6),
              _SettingsSwitch(
                key: const ValueKey('settings-privacy-local'),
                title: '敏感的事只存本机',
                subtitle: '碰到钱、证件、病历这类话题，这段记忆留在手机里，不发给模型',
                value: _privacyLocalOnly,
                onChanged: (v) => setState(() => _privacyLocalOnly = v),
              ),
              const SizedBox(height: 14),
              _ResponsiveRow(
                children: <Widget>[
                  _SettingsTile(
                    key: const ValueKey('settings-open-galaxy'),
                    icon: Icons.auto_awesome_outlined,
                    title: '记忆星图',
                    subtitle: _stars == 0 ? '还没有星，聊聊就有了' : '$_stars 颗星，点开可以让她讲',
                    onTap: widget.memory == null ? null : _openGalaxy,
                  ),
                  _SettingsTile(
                    key: const ValueKey('settings-open-health'),
                    icon: Icons.monitor_heart_outlined,
                    title: '记忆体检',
                    subtitle: '记得多厚、有没有说法打架、哪些星快灭了',
                    onTap: widget.memory == null ? null : _openHealth,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '记住的事 · ${_facts.length} 条',
                      style: AppType.label.copyWith(color: AppPalette.text3),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addFact,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('添加'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
              if (_facts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '还没有记住任何事，聊聊就有了',
                    style: AppType.caption.copyWith(color: AppPalette.text3),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    const double gap = AppSpacing.m;
                    final bool twoColumns = constraints.maxWidth >= 560;
                    final double width = twoColumns
                        ? (constraints.maxWidth - gap) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: <Widget>[
                        for (int i = 0; i < _facts.length; i++)
                          SizedBox(width: width, child: _factCard(i)),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: AppSpacing.s,
                runSpacing: AppSpacing.s,
                children: <Widget>[
                  OutlinedButton.icon(
                    key: const ValueKey('settings-memory-now'),
                    onPressed: widget.onMemoryNow == null || _memoryNowBusy ? null : _runMemoryNow,
                    icon: _memoryNowBusy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.6),
                          )
                        : const Icon(Icons.auto_fix_high_outlined, size: 16),
                    label: const Text('现在就整理一次'),
                    style: _settingsActionStyle(),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('settings-export-memory'),
                    onPressed: widget.memory == null ? null : _exportMemory,
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('导出记忆'),
                    style: _settingsActionStyle(),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('settings-wipe-memory'),
                    onPressed: widget.memory == null ? null : _wipeMemory,
                    icon: const Icon(Icons.delete_forever_outlined, size: 16),
                    label: const Text('清空记忆'),
                    style: _settingsActionStyle(danger: true),
                  ),
                ],
              ),
              if (_exportHint != null) ...[
                const SizedBox(height: 6),
                Text(_exportHint!, style: AppType.caption.copyWith(color: AppPalette.text3)),
              ],
              if (_memoryNowHint != null) ...[
                const SizedBox(height: 6),
                Text(_memoryNowHint!, style: AppType.caption.copyWith(color: AppPalette.text3)),
              ],
              if (widget.onRestoreChat != null) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppPalette.line),
                const SizedBox(height: 14),
                const SectionHeader(label: '会话'),
                const SizedBox(height: AppSpacing.s),
                _SettingsTile(
                  key: const ValueKey('settings-restore-chat'),
                  icon: Icons.history,
                  title: '恢复上次清空的对话',
                  subtitle: '上一段对话还在存档里，点一下合并回当前对话',
                  loading: _restoringChat,
                  onTap: _restoringChat ? null : _restoreChat,
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppPalette.line),
              const SizedBox(height: 14),
              const SectionHeader(label: '主动'),
              const SizedBox(height: AppSpacing.s),
              _SettingsSwitch(
                title: '主动开口',
                subtitle: _proactiveEnabled
                    ? '你不说话时，它会按自己的节奏主动搭话'
                    : '打开后，你不说话时它会主动找你',
                value: _proactiveEnabled,
                onChanged: (v) async {
                  setState(() => _proactiveEnabled = v);
                  await _persist();
                },
              ),
              if (_proactiveEnabled) ...[
                const SizedBox(height: 10),
                _SettingsSwitch(
                  title: '主动分享新鲜事',
                  subtitle: '会真的上网找一条，而不是编',
                  value: _proactiveShareEnabled,
                  onChanged: (v) async {
                    setState(() => _proactiveShareEnabled = v);
                    await _persist();
                  },
                ),
                const SizedBox(height: 14),
                SettingsRow(
                  label: '空闲多久主动找你',
                  description: '安静这么久后，她会考虑说句话',
                  child: DropdownButton<int>(
                    value: _proactiveIdleMinutes,
                    isExpanded: true,
                    items: (<int>{
                      3,
                      5,
                      8,
                      15,
                      30,
                      60,
                      _proactiveIdleMinutes,
                    }.toList()
                          ..sort())
                        .map((m) => DropdownMenuItem<int>(
                              value: m,
                              child: Text('$m 分钟'),
                            ))
                        .toList(),
                    onChanged: (m) async {
                      if (m == null) return;
                      setState(() => _proactiveIdleMinutes = m);
                      await _persist();
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(AppRadii.m),
                  border: Border.all(color: AppPalette.line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '发现箱',
                            style: AppType.caption.copyWith(color: AppPalette.text3),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.inboxCount} 条',
                            key: const ValueKey('settings-inbox-count'),
                            style: AppType.bodySmall.copyWith(color: AppPalette.text1),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _initiativeStatus ?? '还没有试过',
                            style: AppType.caption.copyWith(color: AppPalette.text3),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                      color: AppPalette.line,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.initialNextCheck ?? '下次检查：未安排',
                            key: const ValueKey('settings-next-check'),
                            style: AppType.caption.copyWith(color: AppPalette.text3),
                          ),
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            key: const ValueKey('settings-try-initiative'),
                            onPressed: (_tryingInitiative || widget.onTryInitiative == null)
                                ? null
                                : _tryInitiative,
                            icon: _tryingInitiative
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 1.6),
                                  )
                                : const Icon(Icons.send_outlined, size: 15),
                            label: const Text('现在试一次'),
                            style: _settingsActionStyle(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.inboxCount == 0 && _proactiveShareEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s),
                  child: Text(
                    kIsWeb
                        ? '发现箱为空：Web 版需先用 node server/server.mjs 打开（靠 /fetch 反代才能抓热点），否则只能闲聊不能分享。'
                        : '发现箱为空：网络或来源（HN/V2EX/GitHub）暂时抓不到，后台会每 1.5–3 小时自动重试。',
                    style: AppType.caption.copyWith(color: AppPalette.text3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            key: const ValueKey('settings-section-scene'),
            title: '场景',
            children: <Widget>[
              _SettingsSwitch(
                title: '场景模式（背后的房间）',
                subtitle: '对话浮在房间画面上。往 assets/scene/ 放 room.webp / room.jpg 就能换成自己的房间',
                value: _sceneEnabled,
                onChanged: (v) => setState(() => _sceneEnabled = v),
              ),
              if (_sceneEnabled) ...[
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
                                  child: Text(_sceneLabel(path), style: AppType.bodySmall),
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
                      Text('压暗：', style: AppType.caption.copyWith(color: AppPalette.text3)),
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
                      Text('${(_sceneDim * 100).round()}%', style: AppType.caption.copyWith(color: AppPalette.text2)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            key: _comfySectionKey,
            title: 'ComfyUI',
            children: <Widget>[
              SettingsRow(
                label: 'ComfyUI（电脑上的画图服务）',
                child: TextField(
                  controller: _comfyUrl,
                  decoration: const InputDecoration(
                    hintText: 'http://192.168.1.10:8188',
                    isDense: true,
                    helperText: '手机和电脑要在同一个局域网；ComfyUI 需以 --listen 0.0.0.0 启动',
                  ),
                ),
              ),
              Wrap(
                spacing: AppSpacing.s,
                runSpacing: AppSpacing.s,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: _comfyTesting ? null : _testComfy,
                    icon: const Icon(Icons.wifi_tethering, size: 16),
                    label: const Text('测试连接', style: TextStyle(fontSize: 12)),
                  ),
                  if (ComfyEngine.supported)
                    TextButton.icon(
                      key: const ValueKey('settings-start-comfy'),
                      onPressed: _comfyStarting ? null : _startComfyFromSettings,
                      icon: _comfyStarting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 1.6),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('启动 ComfyUI', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              if (_comfyStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InlineNotice(
                    tone: _comfyTesting
                        ? NoticeTone.info
                        : (_comfyStatus.contains('连不上') ? NoticeTone.danger : NoticeTone.success),
                    message: _comfyStatus,
                  ),
                ),
              const SizedBox(height: 14),
              SettingsRow(
                label: '文生图工作流（她调用 draw 时用）',
                child: TextField(
                  controller: _comfyWorkflow,
                  minLines: 2,
                  maxLines: 6,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '「Save (API Format)」导出的 JSON',
                    isDense: true,
                    helperText: '提示词会自动写进采样器的正向/负向输入；中文会先翻成英文（CLIP 只认英文）',
                  ),
                ),
              ),
              Wrap(
                spacing: AppSpacing.s,
                runSpacing: AppSpacing.s,
                children: <Widget>[
                  for (final ComfyWorkflowTemplate t in kComfyWorkflows)
                    OutlinedButton.icon(
                      key: ValueKey('settings-comfy-template-${t.id}'),
                      onPressed: () => setState(() => _comfyWorkflow.text = t.json),
                      style: _settingsActionStyle(),
                      icon: Icon(
                        comfyWorkflowTemplateOf(_comfyWorkflow.text)?.id == t.id
                            ? Icons.check_circle
                            : Icons.auto_fix_high,
                        size: 16,
                      ),
                      label: Text(t.name),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2, left: 2),
                child: Text(
                  '内置模板：${kComfyWorkflows.map((t) => '${t.name} · ${t.note}').join('；')}'
                  '${comfyWorkflowTemplateOf(_comfyWorkflow.text) == null ? ' · 当前是自定义工作流' : ''}',
                  style: AppType.caption.copyWith(color: AppPalette.text3),
                ),
              ),
              const SizedBox(height: 14),
              SettingsRow(
                label: '去背景工作流（调用 remove_bg 时用）',
                child: TextField(
                  controller: _comfyRemoveBg,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: '需要一个 LoadImage + 抠图节点 + SaveImage 的工作流',
                    isDense: true,
                    helperText: '例：ComfyUI-rembg / BRIA RMBG / INSPYRENET 等自定义节点',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SettingsRow(
                label: '图片编辑工作流（调用 edit_image 时用）',
                child: TextField(
                  controller: _comfyEdit,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'LoadImage → 编辑节点（img2img / inpaint / Kontext / Qwen-Edit）→ SaveImage',
                    isDense: true,
                    helperText: '对话里最近一张图会被自动上传并注入 LoadImage',
                  ),
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
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            key: const ValueKey('settings-section-about'),
            title: '关于',
            children: <Widget>[
              Pill(label: 'build $kBuildTag'),
              const SizedBox(height: 14),
              SelectableText(
                'build=$kBuildTag\n'
                'baseUrl=${_base.text}\n'
                'model=${_model.text}\n'
                'key长度=${widget.initial.apiKey.length}（注入源长度 ${kKeyInjected ? kInjectedKey.length : 0}）',
                style: AppType.mono.copyWith(color: AppPalette.text3),
              ),
              const SizedBox(height: 14),
              Text(
                '所有数据只存在这台设备上：Key、对话、记忆都不经过任何第三方服务器。',
                style: AppType.caption.copyWith(color: AppPalette.text3),
              ),
              const SizedBox(height: 8),
              Text('0.8.0+8', style: AppType.caption.copyWith(color: AppPalette.text3)),
            ],
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

class _AvatarSettingsBlock extends StatelessWidget {
  const _AvatarSettingsBlock({
    required this.title,
    required this.subtitle,
    required this.imageBase64,
    required this.error,
    required this.onPick,
    required this.onReset,
    required this.onDismissError,
    this.pickKey,
    this.useNeutralFallback = false,
  });

  final String title;
  final String subtitle;
  final String? imageBase64;
  final String? error;
  final VoidCallback onPick;
  final VoidCallback? onReset;
  final VoidCallback onDismissError;
  final Key? pickKey;
  final bool useNeutralFallback;

  @override
  Widget build(BuildContext context) {
    final Widget preview = (useNeutralFallback && imageBase64 == null)
        ? Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPalette.surfaceHi,
              border: Border.all(color: AppPalette.line),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 26,
              color: AppPalette.text3,
            ),
          )
        : AvatarMark(size: 56, imageBase64: imageBase64);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        preview,
        const SizedBox(height: AppSpacing.s),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppType.subtitle.copyWith(color: AppPalette.text1),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppType.caption.copyWith(color: AppPalette.text3),
        ),
        const SizedBox(height: AppSpacing.s),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: 0,
          children: <Widget>[
            TextButton(
              key: pickKey,
              onPressed: onPick,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('从相册选择'),
            ),
            TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('恢复默认'),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.s),
          InlineNotice(message: error!, onDismiss: onDismissError),
        ],
      ],
    );
  }
}

/// Two (or more) children share a row when there is room, otherwise stack.
/// Settings used to be one endless column of one-liners; this keeps related
/// entries next to each other on the wide web layout without squeezing phones.
class _ResponsiveRow extends StatelessWidget {
  const _ResponsiveRow({required this.children});

  final List<Widget> children;

  static const double _spacing = AppSpacing.m;
  static const double _breakpoint = 520;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < _breakpoint || children.length < 2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: _spacing),
                children[i],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: _spacing),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A tappable entry tile: icon + title + subtitle + chevron. Used instead of
/// bare `TextButton`s so the memory/session entries line up side by side.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled || loading ? 1 : .55,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.m),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.m,
            AppSpacing.s,
            AppSpacing.m,
          ),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(AppRadii.m),
            border: Border.all(color: AppPalette.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 18, color: AppPalette.primary),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppType.bodySmall.copyWith(
                        color: AppPalette.text1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: AppType.caption.copyWith(color: AppPalette.text3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 2),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.8),
                  ),
                )
              else
                const Icon(Icons.chevron_right, size: 18, color: AppPalette.text4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small, borderless icon button used inside fact cards.
class _FactAction extends StatelessWidget {
  const _FactAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      iconSize: 17,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

/// Shared look for the small action buttons inside settings cards.
ButtonStyle _settingsActionStyle({bool danger = false}) {
  return OutlinedButton.styleFrom(
    foregroundColor: danger ? AppPalette.danger : AppPalette.text2,
    side: BorderSide(
      color: danger ? AppPalette.danger.withValues(alpha: .30) : AppPalette.line,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    visualDensity: VisualDensity.compact,
    textStyle: AppType.bodySmall,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.full),
    ),
  );
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.bodySmall.copyWith(color: AppPalette.text1)),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle, style: AppType.caption.copyWith(color: AppPalette.text3)),
              ],
            ),
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

