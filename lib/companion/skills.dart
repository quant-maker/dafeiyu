import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One thing she can actually do, and how practised she is at it.
///
/// The skill set is fixed (the app knows what it can do); what grows is the
/// experience behind each one. That is what "她会成长" means here: the visible
/// number comes from real use, never from a counter that ticks by itself.
class Skill {
  Skill({
    required this.id,
    required this.name,
    this.xp = 0,
    this.lastAt,
  });

  final String id;
  final String name;
  int xp;
  DateTime? lastAt;

  /// XP needed to leave [level].
  static int xpForLevel(int level) => 12 + level * 8;

  /// 1-based level. Starts at 1 (什么都不会的状态不该显示成 0 级).
  int get level {
    var lv = 1;
    var need = xpForLevel(lv);
    var rest = xp;
    while (rest >= need && lv < 99) {
      rest -= need;
      lv++;
      need = xpForLevel(lv);
    }
    return lv;
  }

  /// Progress inside the current level, 0..1.
  double get levelProgress {
    var lv = 1;
    var need = xpForLevel(lv);
    var rest = xp;
    while (rest >= need && lv < 99) {
      rest -= need;
      lv++;
      need = xpForLevel(lv);
    }
    return (rest / need).clamp(0, 1);
  }

  /// A short phrase the prompt can use.
  String get blurb {
    switch (id) {
      case 'draw':
        return level >= 6 ? '画得又快又稳，敢接复杂构图' : level >= 3 ? '能画，构图还要人提点' : '刚开始摸画笔';
      case 'vision':
        return level >= 6 ? '看得很细，能挑出图里的小毛病' : level >= 3 ? '看得懂图，偶尔看漏细节' : '刚学会看图';
      case 'research':
        return level >= 6 ? '很会翻资料，知道去哪儿找' : level >= 3 ? '会查，但偶尔被标题带偏' : '还不太会查资料';
      case 'memory':
        return level >= 6 ? '记性很好，旧事能自己捞出来' : level >= 3 ? '记得住要紧的事' : '经常忘，需要被提醒';
      case 'translate':
        return level >= 6 ? '中英互译基本不用返工' : '翻得动，偶尔词不达意';
      case 'voice':
        return level >= 4 ? '听得懂你说话，方言也行' : '能听清普通话';
      case 'chat':
        return level >= 20 ? '和你很有默契' : level >= 8 ? '越来越会接你的话' : '还在熟悉你';
      default:
        return '熟练度 $level';
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'xp': xp,
        'lastAt': lastAt?.toIso8601String(),
      };

  static Skill? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] ?? '').toString().trim();
    if (id.isEmpty) return null;
    final xp = raw['xp'];
    return Skill(
      id: id,
      name: (raw['name'] ?? '').toString().trim(),
      xp: xp is num ? xp.toInt() : int.tryParse('$xp') ?? 0,
      lastAt: DateTime.tryParse((raw['lastAt'] ?? '').toString()),
    );
  }
}

/// The full catalogue, in the order it should be shown.
///
/// Every skill here maps to something the app can actually do, so the list
/// never promises a capability that does not exist.
List<Skill> defaultSkills() => <Skill>[
      Skill(id: 'chat', name: '聊天'),
      Skill(id: 'memory', name: '记性'),
      Skill(id: 'research', name: '查资料'),
      Skill(id: 'vision', name: '看图'),
      Skill(id: 'draw', name: '画画'),
      Skill(id: 'translate', name: '翻译'),
      Skill(id: 'voice', name: '听说'),
    ];

/// XP per kind of action. Deliberately small: a level should be a week of use,
/// not a single afternoon, otherwise growth means nothing.
const Map<String, int> kSkillXp = <String, int>{
  'chat': 1,
  'memory': 3,
  'research': 2,
  'vision': 3,
  'draw': 4,
  'translate': 2,
  'voice': 2,
};

class SkillBook {
  SkillBook._(this._skills);

  factory SkillBook.empty() => SkillBook._(defaultSkills());

  static const String storageKey = 'feiyu.skills.v1';

  final List<Skill> _skills;

  List<Skill> get all => List<Skill>.unmodifiable(_skills);

  Skill byId(String id) =>
      _skills.firstWhere((s) => s.id == id, orElse: () => Skill(id: id, name: id));

  static Future<SkillBook> load() async {
    final book = SkillBook.empty();
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(storageKey);
      if (raw == null) return book;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return book;
      for (final entry in decoded) {
        final skill = Skill.fromJson(entry);
        if (skill == null) continue;
        final index = book._skills.indexWhere((s) => s.id == skill.id);
        if (index < 0) continue;
        // Keep the local catalogue name; only the progress is stored.
        book._skills[index]
          ..xp = skill.xp
          ..lastAt = skill.lastAt;
      }
    } catch (_) {
      // A broken file means a fresh skill book, never a broken app.
    }
    return book;
  }

  /// Adds experience and returns true when a level was crossed.
  bool gain(String id, {int xp = 0, DateTime? at}) {
    final amount = xp == 0 ? (kSkillXp[id] ?? 1) : xp;
    final skill = byId(id);
    if (!_skills.any((s) => s.id == id)) return false;
    final before = skill.level;
    skill
      ..xp += amount
      ..lastAt = at ?? DateTime.now();
    return skill.level > before;
  }

  Skill? get strongest {
    final sorted = _skills.toList()..sort((a, b) => b.xp.compareTo(a.xp));
    return sorted.isEmpty ? null : sorted.first;
  }

  Future<void> save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
        storageKey,
        jsonEncode(_skills.map((s) => s.toJson()).toList()),
      );
    } catch (_) {
      // Best effort: the in-memory book still works this session.
    }
  }

  /// The one line that goes into the system prompt.
  String promptLine() {
    final parts = <String>[];
    for (final skill in _skills) {
      if (skill.xp == 0 && skill.id != 'chat') continue;
      parts.add('${skill.name} Lv${skill.level}（${skill.blurb}）');
    }
    if (parts.isEmpty) return '';
    return '你的本事（用得多会长进）：${parts.join('、')}。'
        '提到自己会什么、会不会时，按这个说，别吹也别自我贬低。';
  }
}
