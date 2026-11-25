/// 星图的原料：从对话里抽出「星」（实体）与「边」（关系）。
///
/// 纯解析逻辑，不碰数据库（见 test/graph_test.dart）。
library;

import 'dart:convert';

/// 实体的种类，和 Entities.kind 的取值一致。
enum EntityKind {
  person('person', '人'),
  project('project', '项目'),
  place('place', '地方'),
  topic('topic', '话题'),
  promise('promise', '约定'),
  thing('thing', '事物');

  const EntityKind(this.value, this.label);

  final String value;
  final String label;

  static EntityKind parse(String raw) {
    final t = raw.trim().toLowerCase();
    for (final k in EntityKind.values) {
      if (k.value == t) return k;
    }
    // 模型有时会写中文。
    final zh = {'人': person, '项目': project, '地方': place, '地点': place, '话题': topic, '主题': topic, '约定': promise, '承诺': promise};
    return zh[raw.trim()] ?? thing;
  }
}

class EntityDraft {
  final String name;
  final EntityKind kind;
  final int importance;

  const EntityDraft({required this.name, this.kind = EntityKind.thing, this.importance = 3});

  @override
  String toString() => 'EntityDraft($name, ${kind.value}, $importance)';
}

class EdgeDraft {
  final String src;
  final String dst;

  /// 和 Edges.kind 一致：semantic | temporal | causal | entity | mentions。
  final String kind;
  final String? label;

  const EdgeDraft({required this.src, required this.dst, this.kind = 'mentions', this.label});

  @override
  String toString() => 'EdgeDraft($src -[$kind]-> $dst)';
}

class GraphDraft {
  final List<EntityDraft> entities;
  final List<EdgeDraft> edges;

  const GraphDraft({this.entities = const [], this.edges = const []});

  bool get isEmpty => entities.isEmpty && edges.isEmpty;

  @override
  String toString() => 'GraphDraft(${entities.length} entities, ${edges.length} edges)';
}

String graphExtractionPrompt(String transcript) => '''
从下面的对话里抽出「我以后可能会想起来的人和事」，以及它们之间的关系。

实体 kind 只能用这六个英文值之一：
- person  具体的人（主人、他的同事老周、他的猫）
- project 在做的事、产品、代码项目
- place   地方、场所
- topic   反复出现的主题、兴趣、困扰
- promise 约定或承诺（谁答应谁什么）
- thing   以上都不是的具体事物

规则：
- name 用对话里出现的叫法，2–10 个字，不要带修饰语（写「记忆系统」，不写「他现在在做的那个记忆系统」）。
- importance：1 顺带一提，3 日常，5 重要（关系到长期项目、约定、家人健康）。
- 边只连上面列出的实体，src / dst 必须与实体 name 完全一致；边不许自环。
- 边 kind：mentions（提到）、semantic（同类/相关）、causal（导致）、temporal（先后）、entity（属于）。
- 只抽对话里真的出现过的，不要推理补充。对话很短或没内容就返回空数组。

只输出 JSON 对象，不要解释、不要代码块：
{"entities":[{"name":"…","kind":"topic","importance":3}],"edges":[{"src":"…","dst":"…","kind":"mentions","label":"…"}]}

对话：
$transcript''';

/// 名字归一：去空白、全角空格，统一小写用于匹配（展示仍用原名）。
String normalizeName(String raw) => raw.replaceAll(RegExp(r'\s+'), '').trim();

/// 解析图抽取结果。任何坏输入都退化成空图，永不抛。
GraphDraft parseGraph(String raw) {
  final obj = _extractJsonObject(raw);
  if (obj == null) return const GraphDraft();
  List<dynamic> list(String key) {
    final v = obj[key];
    return v is List ? v : const [];
  }

  final entities = <EntityDraft>[];
  final seen = <String>{};
  for (final item in list('entities')) {
    if (item is! Map) continue;
    final name = normalizeName((item['name'] ?? item['title'] ?? '').toString());
    if (name.isEmpty || name.length > 24) continue;
    if (!seen.add(name)) continue;
    final kind = EntityKind.parse((item['kind'] ?? item['type'] ?? '').toString());
    final imp = _asInt(item['importance'], 3).clamp(1, 5);
    entities.add(EntityDraft(name: name, kind: kind, importance: imp));
  }

  final names = seen;
  final edges = <EdgeDraft>[];
  final pairs = <String>{};
  for (final item in list('edges')) {
    if (item is! Map) continue;
    final src = normalizeName((item['src'] ?? item['from'] ?? '').toString());
    final dst = normalizeName((item['dst'] ?? item['to'] ?? '').toString());
    if (src.isEmpty || dst.isEmpty || src == dst) continue;
    if (!names.contains(src) || !names.contains(dst)) continue;
    if (!pairs.add('$src>$dst')) continue;
    final kind = _edgeKind((item['kind'] ?? item['type'] ?? '').toString());
    final label = (item['label'] ?? '').toString().trim();
    edges.add(EdgeDraft(src: src, dst: dst, kind: kind, label: label.isEmpty ? null : label));
  }
  return GraphDraft(entities: entities, edges: edges);
}

String _edgeKind(String raw) {
  final t = raw.trim().toLowerCase();
  const ok = {'mentions', 'semantic', 'causal', 'temporal', 'entity'};
  return ok.contains(t) ? t : 'mentions';
}

Map<String, dynamic>? _extractJsonObject(String raw) {
  final text = raw.trim();
  final start = text.indexOf('{');
  if (start < 0) return null;
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
    } else if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) {
        try {
          final v = jsonDecode(text.substring(start, i + 1));
          if (v is Map) return v.cast<String, dynamic>();
        } catch (_) {
          return null;
        }
      }
    }
  }
  return null;
}

int _asInt(Object? v, int fallback) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}
