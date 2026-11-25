import 'package:feiyu/memory/graph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseGraph', () {
    test('reads entities and edges', () {
      const raw = '{"entities":[{"name":"记忆系统","kind":"project","importance":5},'
          '{"name":"主人","kind":"person","importance":4}],'
          '"edges":[{"src":"主人","dst":"记忆系统","kind":"causal","label":"在重做"}]}';
      final g = parseGraph(raw);
      expect(g.entities, hasLength(2));
      expect(g.entities.first.kind, EntityKind.project);
      expect(g.entities[1].kind, EntityKind.person);
      expect(g.edges, hasLength(1));
      expect(g.edges.first.kind, 'causal');
      expect(g.edges.first.label, '在重做');
    });

    test('drops edges that point at unknown or self entities', () {
      const raw = '{"entities":[{"name":"甲"},{"name":"乙"}],'
          '"edges":[{"src":"甲","dst":"甲"},{"src":"甲","dst":"丙"},{"src":"甲","dst":"乙"}]}';
      final g = parseGraph(raw);
      expect(g.entities, hasLength(2));
      expect(g.edges, hasLength(1));
      expect(g.edges.first.src, '甲');
      expect(g.edges.first.dst, '乙');
    });

    test('normalizes whitespace and dedupes names', () {
      const raw = '{"entities":[{"name":" 大 肥 鱼 "},{"name":"大肥鱼"}],"edges":[]}';
      final g = parseGraph(raw);
      expect(g.entities, hasLength(1));
      expect(g.entities.first.name, '大肥鱼');
    });

    test('maps chinese kinds and unknown kinds', () {
      const raw = '{"entities":[{"name":"老周","kind":"人"},{"name":"咖啡","kind":"不知道"}]}';
      final g = parseGraph(raw);
      expect(g.entities[0].kind, EntityKind.person);
      expect(g.entities[1].kind, EntityKind.thing);
    });

    test('clamps importance and rejects absurd names', () {
      final long = 'x' * 40;
      final raw = '{"entities":[{"name":"甲","importance":9},{"name":"$long"}]}';
      final g = parseGraph(raw);
      expect(g.entities, hasLength(1));
      expect(g.entities.first.importance, 5);
    });

    test('unknown edge kind falls back to mentions', () {
      const raw = '{"entities":[{"name":"甲"},{"name":"乙"}],'
          '"edges":[{"src":"甲","dst":"乙","kind":"friendship"}]}';
      expect(parseGraph(raw).edges.first.kind, 'mentions');
    });

    test('prose or broken json means an empty graph', () {
      expect(parseGraph('没什么可记的').isEmpty, isTrue);
      expect(parseGraph('{"entities":[').isEmpty, isTrue);
      expect(parseGraph('').isEmpty, isTrue);
    });

    test('prompt keeps the constraints and transcript', () {
      final p = graphExtractionPrompt('主人：我在弄星图');
      expect(p, contains('person'));
      expect(p, contains('不许自环'));
      expect(p, contains('主人：我在弄星图'));
    });
  });
}
