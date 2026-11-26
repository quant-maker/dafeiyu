import 'dart:convert';

import 'package:feiyu/comfy/comfy.dart';
import 'package:feiyu/comfy/workflows.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> parse(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;

Map<String, dynamic> node(Map<String, dynamic> wf, String id) =>
    wf[id] as Map<String, dynamic>;

void main() {
  test('SD-Turbo keeps prompting its two CLIPTextEncode nodes', () {
    final wf = patchWorkflow(
      parse(kComfySdTurboWorkflow),
      prompt: '一只鲸鱼',
      negative: '糊',
      seed: 7,
    );
    expect((node(wf, '6')['inputs'] as Map)['text'], '一只鲸鱼');
    expect((node(wf, '7')['inputs'] as Map)['text'], '糊');
    expect((node(wf, '3')['inputs'] as Map)['seed'], 7);
  });

  test('Z-Image prompt lands in CLIPTextEncode, negative stays zeroed', () {
    final wf = patchWorkflow(
      parse(kComfyZImageTurboWorkflow),
      prompt: '海边的小鲸鱼',
      negative: '糊',
      seed: 42,
    );
    final positive = node(wf, '27')['inputs'] as Map;
    expect(positive['text'], '海边的小鲸鱼');
    final negative = node(wf, '33')['inputs'] as Map;
    // ConditioningZeroOut has no text input; injecting one would break the
    // /prompt validation.
    expect(negative.containsKey('text'), isFalse);
    final sampler = node(wf, '3')['inputs'] as Map;
    expect(sampler['seed'], 42);
    expect(sampler['steps'], 8);
  });

  test('built-in templates resolve by id and by exact content', () {
    expect(comfyWorkflowTemplate('sd-turbo')!.json, kComfySdTurboWorkflow);
    expect(comfyWorkflowTemplate('z-image-turbo')!.json, kComfyZImageTurboWorkflow);
    expect(comfyWorkflowTemplateOf(kComfyZImageTurboWorkflow)!.id, 'z-image-turbo');
    expect(comfyWorkflowTemplateOf('{"1":{}}'), isNull);
  });

  test('the old two-step SD-Turbo copy in settings is upgraded', () {
    final String oldDefault =
        kComfySdTurboWorkflow.replaceFirst('"steps": 4', '"steps": 2');
    expect(
      (parse(comfyWorkflowUpgrade(oldDefault))['3'] as Map)['inputs']['steps'],
      4,
    );
    // A workflow someone actually edited must survive untouched.
    const String custom = '{"3":{"class_type":"KSampler","inputs":{"steps":2}}}';
    expect(comfyWorkflowUpgrade(custom), custom);
  });
}
