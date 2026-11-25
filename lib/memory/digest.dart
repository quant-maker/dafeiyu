/// 记忆抽取与层叠摘要的「工艺」：提示词 + 解析。
///
/// 这里是纯函数，不碰数据库也不碰网络，方便单测（test/digest_test.dart）。
/// 提示词遵循 docs/memory-design.md 的 KEEP / DROP 清单：
///  KEEP 决定与理由、偏好、在做的事、承诺、具体的数字与名字、情绪转折；
///  DROP 寒暄、重复、已经写在别处的内容、模型自己的发挥。
library;

import 'dart:convert';

/// 一条待落库的情景。
class EpisodeDraft {
  final String title;
  final String body;
  final int importance;

  const EpisodeDraft({required this.title, required this.body, this.importance = 3});

  @override
  String toString() => 'EpisodeDraft($title, ${body.length} chars, imp=$importance)';
}

/// 抽出情景用的提示词。[transcript] 是已经渲染好的「主人：… / 我：…」文本。
String episodeExtractionPrompt(String transcript) => '''
下面是一段我和主人的对话。请把它写成 1–3 条「情景记忆」，每条是一小块以后还能想起来的事。

要求：
- 写成我的日记口吻，第一人称「我」，过去时。不要复述对话，写发生了什么、我记住了什么。
- 每条 60–160 字。标题不超过 14 个字。
- 只保留值得记住的：主人的决定或结论、他的偏好与厌恶、他正在做的事与进展、他答应过的或我答应过的、具体的人名地名数字、情绪明显转折的地方。
- 不要写：寒暄、应答、重复、我刚才说过的话、从上面能推出来的废话。
- importance：1 琐事，3 日常，5 重要（涉及承诺、健康、重要决定）。
- 如果这段对话确实没有值得记的，返回空数组 []。

只输出 JSON 数组，不要解释、不要代码块：
[{"title":"…","body":"…","importance":3}]

对话：
$transcript''';

/// 日结：把一天的多条情景写成一篇日记。
String dayCardPrompt({required String dayLabel, required List<String> episodes}) => '''
这是我 $dayLabel 的记忆碎片，请把它们写成一篇日记，作为这一天的「日结」。

要求：
- 第一人称「我」，200–400 字，按时间顺序，可以带一点我的口气，但不要编造没发生的事。
- 保留：具体发生的事、主人的决定与理由、他的状态与偏好、约定、数字与名字。
- 合并重复的碎片；寒暄与无信息量的内容直接丢掉。
- 结尾不要总结升华，不要写「这一天很充实」这类空话。

只输出日记正文，不要标题、不要解释。

碎片：
${episodes.map((e) => '- $e').join('\n')}''';

/// 周结 / 月结：把上一层的多篇合并成一篇。
String rollupPrompt({required String label, required String level, required List<String> cards}) => '''
下面是$level的各段记录，请合并成一段$level回顾（$label）。

要求：
- 第一人称「我」，按主题归并而不是按时间罗列；重复的只留一次。
- 保留：长期的偏好与习惯、反复出现的人和事、做过的决定与理由、尚未完成的承诺。
- 丢掉：一次性的琐碎细节、当天情绪、寒暄。
- 300–600 字，正文直接写，不要标题与总结句。

只输出正文。

记录：
${cards.map((c) => '· $c').join('\n')}''';

/// 事实抽取（L2）：比情景更短、更可校验的条目。
String factExtractionPrompt(String transcript) => '''
从下面的对话里抽取「关于主人的稳定事实」，每条一句短句，不超过 30 字。

只抽：身份与背景、长期偏好与厌恶、习惯、正在做的项目、重要关系、明确的计划。
不要抽：一次性的情绪、当下的临时状态、我已经知道的一般常识、推测。
没有新事实就输出空数组。

只输出 JSON 数组：["…","…"]

对话：
$transcript''';

/// 把模型输出里夹带的 ```json 围栏、前后说明剥掉，取第一个完整的 JSON 数组。
String extractJsonArray(String raw) {
  final text = raw.trim();
  final start = text.indexOf('[');
  if (start < 0) return '[]';
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < text.length; i++) {
    final c = text[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }
    if (c == '"') {
      inString = true;
    } else if (c == '[') {
      depth++;
    } else if (c == ']') {
      depth--;
      if (depth == 0) return text.substring(start, i + 1);
    }
  }
  return '[]';
}

/// 模型到底有没有产出 JSON 数组（而不是一段散文）。
bool _looksLikeJsonArray(String raw) {
  final t = raw.trim();
  if (t.startsWith('[')) return true;
  return RegExp(r'\[\s*\{').hasMatch(t) || RegExp(r'\[\s*"').hasMatch(t);
}

/// 解析情景数组。解析不出来时退化成一条「原文摘录」，永不抛异常。
List<EpisodeDraft> parseEpisodeDrafts(String raw) {
  if (_looksLikeJsonArray(raw)) {
    final data = _decode(extractJsonArray(raw));
    if (data is List) {
      final out = <EpisodeDraft>[];
      for (final item in data) {
        if (item is! Map) continue;
        final body = (item['body'] ?? item['text'] ?? item['summary'] ?? '').toString().trim();
        if (body.isEmpty) continue;
        final title = (item['title'] ?? '').toString().trim();
        final imp = _asInt(item['importance'], 3).clamp(1, 5);
        out.add(EpisodeDraft(
          title: title.isEmpty ? _autoTitle(body) : title,
          body: body,
          importance: imp,
        ));
      }
      return out;
    }
  }
  final flat = cleanModelText(raw);
  if (flat.isEmpty) return const [];
  return [EpisodeDraft(title: _autoTitle(flat), body: flat)];
}

/// 解析字符串数组（事实抽取）。
List<String> parseFactLines(String raw) {
  if (_looksLikeJsonArray(raw)) {
    final data = _decode(extractJsonArray(raw));
    if (data is List) {
      return data
          .map((e) => e is Map ? (e['text'] ?? e['content'] ?? '').toString() : e.toString())
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }
  return cleanModelText(raw)
      .split(RegExp(r'[\n；;]+'))
      .map((e) => e.replaceFirst(RegExp(r'^[-*\d.、\s]+'), '').trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

/// 去掉代码块围栏、开头的客套话，只留下正文。
String cleanModelText(String raw) {
  var t = raw.trim();
  t = t.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '').replaceAll(RegExp(r'\s*```$'), '');
  t = t.replaceFirst(RegExp(r'^(好的|好，|以下是|这是)[^\n]{0,20}\n+'), '');
  return t.trim();
}

/// 解析 JSON；坏输入返回 null，不抛。
Object? _decode(String json) {
  try {
    return jsonDecode(json);
  } catch (_) {
    return null;
  }
}

int _asInt(Object? v, int fallback) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

String _autoTitle(String body) {
  final firstLine = body.split(RegExp(r'[。！？\n]')).first.trim();
  final t = firstLine.isEmpty ? body.trim() : firstLine;
  return t.length <= 14 ? t : t.substring(0, 14);
}
