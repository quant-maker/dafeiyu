import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'feeds/footprints.dart';
import 'providers.dart';
import 'feeds/footprints_page.dart';
import 'memory/archive.dart';
import 'scene/scene_stage.dart';

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

class Settings {
  String baseUrl;
  String apiKey;
  String model;
  String persona;
  bool memoryEnabled;
  bool proactiveEnabled;
  bool sceneEnabled;
  String embeddingModel;
  String asrModel;
  String provider;
  Map<String, String> apiKeys;
  bool ttsEnabled;
  int proactiveIdleMinutes;

  Settings({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.persona,
    this.memoryEnabled = true,
    this.proactiveEnabled = false,
    this.sceneEnabled = true,
    this.embeddingModel = 'Qwen/Qwen3-Embedding-4B',
    this.asrModel = 'gpt-4o-mini-transcribe',
    this.provider = 'deepseek',
    this.apiKeys = const {},
    this.ttsEnabled = false,
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
      embeddingModel: pick(j['embeddingModel'] as String?, 'Qwen/Qwen3-Embedding-4B'),
      asrModel: pick(j['asrModel'] as String?, 'gpt-4o-mini-transcribe'),
      provider: pick(j['provider'] as String?, 'deepseek'),
      apiKeys: ((j['apiKeys'] as Map?) ?? const {}).map((k, v) => MapEntry(k.toString(), v.toString())),
      ttsEnabled: j['ttsEnabled'] as bool? ?? false,
      proactiveIdleMinutes: (j['proactiveIdleMinutes'] as num?)?.toInt() ?? 8,
    );
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
        'embeddingModel': embeddingModel,
        'asrModel': asrModel,
        'provider': provider,
        'apiKeys': apiKeys,
        'ttsEnabled': ttsEnabled,
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
    return '你记得关于主人的这些事（长期记忆，自然使用，不要逐条复述）：\n' + facts.map((f) => '- $f').join('\n');
  }
}

class Message {
  final String role;
  String content;
  final String? imageBase64;
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
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF4AA3FF), brightness: Brightness.dark);
    return MaterialApp(
      title: '大肥鱼',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF0B1220),
      ),
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
  final stt.SpeechToText _speech = stt.SpeechToText();
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
  Timer? _idleTimer;
  int _proactiveCount = 0;
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
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
    _dots.dispose();
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
      final path = '${dir.path}/feiyu_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000), path: path);
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
    final base = s.baseUrl.endsWith('/') ? s.baseUrl.substring(0, s.baseUrl.length - 1) : s.baseUrl;
    final req = http.MultipartRequest('POST', Uri.parse('$base/audio/transcriptions'))
      ..headers['authorization'] = 'Bearer ${s.apiKey}'
      ..fields['model'] = s.asrModel
      ..fields['language'] = 'zh'
      ..files.add(await http.MultipartFile.fromPath('file', path, filename: 'voice.m4a'));
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) throw Exception('HTTP ${streamed.statusCode}: ${body.substring(0, body.length.clamp(0, 160))}');
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
      '现在是 $today。下面的对话记录可能跨越好几天，注意日期。'
          '如果对方问起以前聊过的事，先看记录和记忆；确实没有就直说没印象，不要编。',
      if (s.memoryEnabled) _memory.asPrompt(),
      _recentDigest(),
      '你可以调用三个工具：'
          '① fetch_url 抓网页正文（查资料、看链接时用，别凭空猜网页内容）；'
          '② remember 把值得长期记住的事记下来（对方的偏好、约定、正在做的项目、重要经历），'
          '一条一句话，不要记流水账；'
          '③ footprint 把当下这一刻收进足迹——只有真的打动你、值得多年后回看的瞬间才用，'
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
        return tail.map((m) => m.toJson());
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
    final base = s.baseUrl.endsWith('/') ? s.baseUrl.substring(0, s.baseUrl.length - 1) : s.baseUrl;
    final client = http.Client();
    _client = client;
    final req = http.Request('POST', Uri.parse('$base/chat/completions'))
      ..headers.addAll({
        'content-type': 'application/json',
        'authorization': 'Bearer ${s.apiKey}',
      })
      ..body = jsonEncode({
        'model': s.model,
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
              setState(() {
                target.content = buffer.toString();
                _waitingFirstToken = false;
              });
            }
            _scrollToEnd();
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
        .replaceAll(RegExp(r'(?is)<script.*?</script>'), ' ')
        .replaceAll(RegExp(r'(?is)<style.*?</style>'), ' ')
        .replaceAll(RegExp(r'(?is)<head.*?</head>'), ' ')
        .replaceAll(RegExp(r'(?s)<[^>]+>'), ' ')
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
    try {
      await _tts.stop();
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.52);
      await _tts.setPitch(1.05);
      // Speak the first couple of sentences; long essays get tiring to hear.
      final spoken = text.length > 220 ? '${text.substring(0, 220)}…' : text;
      await _tts.speak(spoken);
    } catch (e) {
      debugPrint('[feiyu] tts FAILED: $e');
    }
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
    return '今天早些时候的摘要：\n' + pick.map((e) => '- ${e.text}').join('\n');
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
    return '找到这些旧记录：\n' + hits.map((e) => '【${e.day}】${e.text}').join('\n\n');
  }

  // ---------------- footprints ----------------

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
      mood: _mood,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFF7CC4FF), Color(0xFF2F6FD0)]),
                  boxShadow: [BoxShadow(color: const Color(0xFF4AA3FF).withValues(alpha: .35), blurRadius: 12)],
                ),
                child: const Center(child: Text('🐟', style: TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('大肥鱼', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: .3)),
                  Text(
                    _statusLine(),
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: .5)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(onPressed: _openFootprints, icon: const Icon(Icons.photo_library_outlined), tooltip: '她的足迹'),
            IconButton(onPressed: _clear, icon: const Icon(Icons.auto_awesome_outlined), tooltip: '新会话'),
            IconButton(onPressed: _openSettings, icon: const Icon(Icons.tune), tooltip: '设置'),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            if (_error != null) _errorBar(),
            Expanded(child: _messages.isEmpty ? _emptyState() : _messageList()),
            if (_pendingImage != null) _pendingImageBar(),
            if (_listening) _listeningBar(),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _errorBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF3B1D22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7A2A35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Color(0xFFFF8A8A)),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(_error!, style: const TextStyle(color: Color(0xFFFFC2C2), fontSize: 12))),
          InkWell(
            onTap: () => setState(() => _error = null),
            child: const Icon(Icons.close, size: 16, color: Color(0xFFFFC2C2)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    const samples = ['今天有什么好玩的', '帮我看看这张图', '你还记得我吗'];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF7CC4FF), Color(0xFF2F6FD0)]),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF4AA3FF).withValues(alpha: .3), blurRadius: 34, spreadRadius: 2)
                ],
              ),
              child: const Center(child: Text('🐟', style: TextStyle(fontSize: 44))),
            ),
            const SizedBox(height: 20),
            const Text('今天想聊点什么？', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '可以按麦克风说话，也可以发一张图给它看。  ·  $kBuildTag',
              style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: .45)),
            ),
            const SizedBox(height: 26),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: samples
                  .map((t) => InkWell(
                        onTap: () => _send(t),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withValues(alpha: .1)),
                          ),
                          child: Text(t, style: const TextStyle(fontSize: 12.5)),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 56, 14, 20),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        final mine = m.role == 'user';
        final typing = !mine && _busy && _waitingFirstToken && m.content.isEmpty;
        return _message(m, mine, typing, i);
      },
    );
  }

  /// Her replies are film subtitles etched into the glass: no bubble, layered
  /// shadows for legibility. The owner keeps a compact pill so the back-and-forth
  /// still reads like a conversation.
  Widget _message(Message m, bool mine, bool typing, int index) {
    final showLabel = !mine && (index == 0 || _messages[index - 1].role != 'assistant');
    final isNewest = index == _messages.length - 1;

    if (mine) return _userPill(m, typing);

    final text = SelectableText(
      m.content,
      style: _etched(size: 19.5),
    );

    final body = Padding(
      padding: EdgeInsets.only(left: 6, right: 44, top: showLabel ? 14 : 10, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🐟',
                    style: TextStyle(fontSize: 12, shadows: _etchShadows),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '大肥鱼',
                    style: TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9FD0FF).withValues(alpha: .9),
                      shadows: _etchShadows,
                    ),
                  ),
                ],
              ),
            ),
          typing ? _TypingDots(controller: _dots) : text,
        ],
      ),
    );

    if (!isNewest) return body;
    // The newest line breathes in instead of popping.
    return TweenAnimationBuilder<double>(
      key: ValueKey(m),
      tween: Tween(begin: .62, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOut,
      builder: (_, value, child) => Opacity(opacity: value, child: child),
      child: body,
    );
  }

  static const _etchShadows = [
    Shadow(color: Color(0xCC000000), blurRadius: 3, offset: Offset(0, 1)),
    Shadow(color: Color(0xB3000000), blurRadius: 16, offset: Offset(0, 3)),
    Shadow(color: Color(0x33FFFFFF), blurRadius: 1, offset: Offset(0, -1)),
  ];

  /// Text that looks engraved into the pane: dark lower edge, lit upper edge,
  /// and a faint cool halo.
  TextStyle _etched({required double size}) => TextStyle(
        fontSize: size,
        height: 1.62,
        letterSpacing: .2,
        fontWeight: FontWeight.w500,
        color: const Color(0xFFF4F9FF),
        shadows: _etchShadows,
      );

  Widget _userPill(Message m, bool typing) {
    const accent = Color(0xFF4AA3FF);
    final radius = BorderRadius.circular(16);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 6, left: 56),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .72),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .26),
            borderRadius: radius,
            border: Border.all(color: accent.withValues(alpha: .30), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Text(
            m.content,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: Color(0xFFEAF4FF),
              shadows: [Shadow(color: Color(0xAA000000), blurRadius: 6, offset: Offset(0, 1))],
            ),
          ),
        ),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF131E32),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 14, offset: const Offset(0, 4))],
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
    );
  }
}

class _TypingDots extends AnimatedWidget {
  const _TypingDots({required AnimationController controller}) : super(listenable: controller);
  @override
  Widget build(BuildContext context) {
    final t = (listenable as AnimationController).value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final phase = (t + i * 0.2) % 1.0;
        final opacity = 0.25 + 0.75 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 6),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: opacity.clamp(0.2, 1.0)),
          ),
        );
      }),
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
  late bool _ttsEnabled;
  late String _provider;
  late Map<String, String> _keys;
  late final TextEditingController _asr;
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
    _ttsEnabled = widget.initial.ttsEnabled;
    _provider = widget.initial.provider;
    _keys = Map.of(widget.initial.apiKeys);
    _asr = TextEditingController(text: widget.initial.asrModel);
    _proactiveIdleMinutes = widget.initial.proactiveIdleMinutes;
    _loadModels();
  }

  @override
  void dispose() {
    _base.dispose();
    _asr.dispose();
    _key.dispose();
    _model.dispose();
    _persona.dispose();
    super.dispose();
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
      ttsEnabled: _ttsEnabled,
      provider: _provider,
      apiKeys: {..._keys, _provider: _key.text.trim()},
      asrModel: _asr.text.trim(),
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
          DropdownButtonFormField<String>(
            initialValue: _models.contains(_model.text) ? _model.text : null,
            isExpanded: true,
            decoration: const InputDecoration(hintText: '选择模型（填好 Key 后点右边刷新）'),
            items: _models
                .map((id) => DropdownMenuItem(
                      value: id,
                      child: Text(id, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _model.text = v);
            },
          ),
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
            subtitle: const Text('回答完用系统语音念出来（前三句左右）'),
          ),
          const _Label('语音识别模型（走网关转写，不需要手机自带识别）'),
          TextField(
            controller: _asr,
            decoration: const InputDecoration(hintText: 'gpt-4o-mini-transcribe', isDense: true),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _sceneEnabled,
            onChanged: (v) => setState(() => _sceneEnabled = v),
            title: const Text('场景模式（玻璃后的客厅）'),
            subtitle: const Text('把对话印在玻璃上，背后是房间。往 assets/scene/ 放视频就自动换成真实画面'),
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
