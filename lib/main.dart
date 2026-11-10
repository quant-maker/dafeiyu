import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  int proactiveIdleMinutes;

  Settings({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.persona,
    this.memoryEnabled = true,
    this.proactiveEnabled = false,
    this.proactiveIdleMinutes = 8,
  });

  static const _k = 'feiyu.settings.v3';

  static Future<Settings> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw == null) {
      return Settings(
        baseUrl: defaultBaseUrl(),
        apiKey: kKeyInjected ? kInjectedKey : '',
        model: kDefaultModel,
        persona: kPresetPersona,
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
  Message(this.role, this.content, {this.imageBase64});

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
  Memory _memory = Memory();

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
    if (_listening) {
      await _speech.stop();
      setState(() {
        _listening = false;
        _voiceHint = '';
      });
      return;
    }
    try {
      final ok = await _speech.initialize(
        onError: (e) => setState(() {
          _listening = false;
          _error = '语音识别不可用：${e.errorMsg}';
        }),
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted) setState(() => _listening = false);
        },
      );
      if (!ok) {
        setState(() => _error = '这台设备没有可用的语音识别');
        return;
      }
      setState(() {
        _listening = true;
        _voiceHint = '正在听…';
      });
      await _speech.listen(
        localeId: 'zh_CN',
        onResult: (r) {
          if (r.recognizedWords.isEmpty) return;
          setState(() {
            _input.text = r.recognizedWords;
            _voiceHint = r.finalResult ? '' : r.recognizedWords;
          });
          if (r.finalResult) setState(() => _listening = false);
        },
        listenOptions: stt.SpeechListenOptions(partialResults: true, cancelOnError: true),
      );
    } catch (e) {
      setState(() {
        _listening = false;
        _error = '语音启动失败：$e';
      });
    }
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
  ];

  String _systemPrompt(Settings s) => [
        if (s.persona.trim().isNotEmpty) s.persona.trim(),
        if (s.memoryEnabled) _memory.asPrompt(),
        '你可以调用 fetch_url 抓取网页正文。需要查资料、看链接里写了什么时就用它，'
            '不要凭空猜网页内容；抓到内容后用自己的话回答，别整段照抄。',
      ].where((x) => x.isNotEmpty).join('\n\n');

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
      ..._messages
          .where((m) => m.content.trim().isNotEmpty || m.imageBase64 != null)
          .map((m) => m.toJson()),
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
      });

  /// Visible diagnostics: tells you exactly which piece is missing.
  String _statusLine() {
    if (_busy) return _activity.isNotEmpty ? _activity : '正在想…';
    final s = _settings;
    if (s == null) return '加载设置中…';
    final keyState = s.apiKey.isEmpty ? 'key✗' : 'key✓${s.apiKey.length}';
    final host = Uri.tryParse(s.baseUrl)?.host ?? s.baseUrl;
    return '${s.model.isEmpty ? '未选模型' : s.model} · $keyState · $host';
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF122444), Color(0xFF0B1220), Color(0xFF070C16)],
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        final mine = m.role == 'user';
        final typing = !mine && _busy && _waitingFirstToken && m.content.isEmpty;
        return _bubble(m, mine, typing);
      },
    );
  }

  Widget _bubble(Message m, bool mine, bool typing) {
    const accent = Color(0xFF4AA3FF);
    final bubble = Container(
      margin: EdgeInsets.only(bottom: 12, left: mine ? 44 : 0, right: mine ? 0 : 44),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: mine
            ? const LinearGradient(
                colors: [Color(0xFF3E86E0), Color(0xFF2A5FB4)], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: mine ? null : const Color(0xFF16223A),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 6),
          bottomRight: Radius.circular(mine ? 6 : 18),
        ),
        border: mine ? null : Border.all(color: Colors.white.withValues(alpha: .06)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.imageBase64 != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(base64Decode(m.imageBase64!), width: 200, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
          ],
          if (typing)
            _TypingDots(controller: _dots)
          else
            SelectableText(m.content, style: const TextStyle(fontSize: 14.5, height: 1.45, color: Colors.white)),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!mine) ...[
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: .16),
              border: Border.all(color: accent.withValues(alpha: .4)),
            ),
            child: const Center(child: Text('🐟', style: TextStyle(fontSize: 14))),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(child: bubble),
      ],
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
    _proactiveIdleMinutes = widget.initial.proactiveIdleMinutes;
    _loadModels();
  }

  @override
  void dispose() {
    _base.dispose();
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
