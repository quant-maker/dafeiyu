import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Minimal client for a local ComfyUI instance.
///
/// Instead of shipping a fixed workflow we accept any workflow exported with
/// "Save (API Format)" and patch its prompt fields — that keeps working when the
/// owner switches between SD1.5 / SDXL / Flux graphs.
class ComfyClient {
  ComfyClient(this.baseUrl);

  /// Browsers cannot call another port cross-origin, so on web everything goes
  /// through the local server's /comfy proxy instead. The caller decides which
  /// world it is in, which keeps this file free of Flutter imports.
  static String resolve(String configured, {bool web = false}) =>
      web ? '${Uri.base.origin}/comfy' : configured;

  factory ComfyClient.resolved(String configured, {bool web = false}) =>
      ComfyClient(resolve(configured, web: web));

  final String baseUrl;

  String get _base {
    var b = baseUrl.trim();
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    return b;
  }

  Future<bool> ping({Duration timeout = const Duration(seconds: 6)}) async {
    try {
      final res = await http.get(Uri.parse('$_base/system_stats')).timeout(timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// True when every one of these node types is installed.
  Future<bool> hasNodes(List<String> types) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/object_info'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return false;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return types.every(j.containsKey);
    } catch (_) {
      return false;
    }
  }

  /// Checkpoints this ComfyUI can load. Empty means nothing is installed.
  Future<List<String>> checkpoints() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/object_info/CheckpointLoaderSimple'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return const [];
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final node = (j['CheckpointLoaderSimple'] as Map?) ;
      final required = (node?['input'] as Map?)?['required'] as Map?;
      final ckpt = required?['ckpt_name'];
      // shape: [[names...], {...}]
      if (ckpt is List && ckpt.isNotEmpty) {
        final names = ckpt.first;
        if (names is List) return names.map((e) => e.toString()).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Runs in the background right now.
  Future<int> queueLength() async {
    try {
      final res = await http.get(Uri.parse('$_base/queue')).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return 0;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final running = (j['queue_running'] as List?)?.length ?? 0;
      final pending = (j['queue_pending'] as List?)?.length ?? 0;
      return running + pending;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearQueue() async {
    await http
        .post(
          Uri.parse('$_base/queue'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'clear': true}),
        )
        .timeout(const Duration(seconds: 10));
  }

  /// Pushes a picture into ComfyUI's input folder and returns its name, which
  /// is what a LoadImage node expects.
  Future<String> uploadImage(List<int> bytes, {String? name}) async {
    final filename = name ?? 'feiyu_${DateTime.now().millisecondsSinceEpoch}.png';
    final req = http.MultipartRequest('POST', Uri.parse('$_base/upload/image'))
      ..files.add(http.MultipartFile.fromBytes('image', bytes, filename: filename))
      ..fields['overwrite'] = 'true';
    final res = await req.send().timeout(const Duration(seconds: 30));
    final body = await res.stream.bytesToString();
    if (res.statusCode != 200) {
      throw Exception('上传图片失败 HTTP ${res.statusCode}: ${_short(body)}');
    }
    final j = jsonDecode(body) as Map<String, dynamic>;
    final uploaded = (j['name'] ?? filename) as String;
    final sub = (j['subfolder'] ?? '') as String;
    return sub.isEmpty ? uploaded : '$sub/$uploaded';
  }

  /// Submits a workflow and returns the prompt id.
  Future<String> submit(Map<String, dynamic> workflow) async {
    final clientId = DateTime.now().microsecondsSinceEpoch.toString();
    final res = await http
        .post(
          Uri.parse('$_base/prompt'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'prompt': workflow, 'client_id': clientId}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('提交失败 HTTP ${res.statusCode}: ${_short(res.body)}');
    }
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final id = j['prompt_id'] as String?;
    if (id == null) throw Exception('ComfyUI 没有返回 prompt_id：${_short(res.body)}');
    return id;
  }

  /// Polls history until the job finishes, then downloads the images.
  Future<List<Uint8List>> waitForImages(
    String promptId, {
    Duration timeout = const Duration(minutes: 3),
    void Function(Duration elapsed)? onTick,
  }) async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < timeout) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      onTick?.call(DateTime.now().difference(start));
      try {
        final res = await http
            .get(Uri.parse('$_base/history/$promptId'))
            .timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;
        final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final entry = j[promptId] as Map<String, dynamic>?;
        if (entry == null) continue;

        // A failed graph never produces outputs; report the real reason.
        final status = entry['status'] as Map<String, dynamic>?;
        if (status != null && status['status_str'] == 'error') {
          var detail = 'ComfyUI 执行失败';
          final messages = status['messages'] as List?;
          if (messages != null) {
            for (final m in messages) {
              if (m is List && m.length > 1 && m.first == 'execution_error') {
                final info = m[1] as Map?;
                final msg = info?['exception_message']?.toString();
                final node = info?['node_type']?.toString();
                if (msg != null) {
                  detail = node == null ? msg : '$node: $msg';
                }
              }
            }
          }
          throw Exception(detail.trim());
        }
        final outputs = entry['outputs'] as Map<String, dynamic>? ?? const {};
        final files = <String>[];
        for (final node in outputs.values) {
          final imgs = (node as Map)['images'] as List?;
          if (imgs == null) continue;
          for (final img in imgs) {
            final m = img as Map;
            final name = m['filename'] as String?;
            if (name == null) continue;
            final sub = (m['subfolder'] ?? '') as String;
            final type = (m['type'] ?? 'output') as String;
            files.add('$_base/view?filename=${Uri.encodeComponent(name)}'
                '&subfolder=${Uri.encodeComponent(sub)}&type=$type');
          }
        }
        if (files.isEmpty) continue;
        final bytes = <Uint8List>[];
        for (final url in files.take(4)) {
          final img = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
          if (img.statusCode == 200) bytes.add(img.bodyBytes);
        }
        if (bytes.isNotEmpty) return bytes;
      } catch (_) {
        // keep polling
      }
    }
    throw TimeoutException('等了 ${timeout.inMinutes} 分钟还没出图，检查电脑上的队列');
  }

  static String _short(String s) => s.length > 160 ? s.substring(0, 160) : s;
}

/// SD-Turbo / LCM / Lightning style checkpoints converge in a handful of steps.
bool isFastCheckpoint(String name) {
  final n = name.toLowerCase();
  return n.contains('turbo') || n.contains('lcm') || n.contains('lightning') || n.contains('schnell');
}

/// A plain text-to-image graph that works with the given checkpoint.
Map<String, dynamic> defaultTxt2Img(
  String ckptName, {
  int size = 512,
  int? steps,
  double? cfg,
}) {
  final fast = isFastCheckpoint(ckptName);
  return {
    '3': {
      'class_type': 'KSampler',
      'inputs': {
        'seed': 1,
        'steps': steps ?? (fast ? 3 : 20),
        'cfg': cfg ?? (fast ? 1.0 : 7.0),
        'sampler_name': fast ? 'euler' : 'dpmpp_2m',
        'scheduler': fast ? 'normal' : 'karras',
        'denoise': 1.0,
        'model': ['4', 0],
        'positive': ['6', 0],
        'negative': ['7', 0],
        'latent_image': ['5', 0],
      },
    },
    '4': {
      'class_type': 'CheckpointLoaderSimple',
      'inputs': {'ckpt_name': ckptName},
    },
    '5': {
      'class_type': 'EmptyLatentImage',
      'inputs': {'width': size, 'height': size, 'batch_size': 1},
    },
    '6': {
      'class_type': 'CLIPTextEncode',
      'inputs': {'text': '', 'clip': ['4', 1]},
    },
    '7': {
      'class_type': 'CLIPTextEncode',
      'inputs': {'text': '', 'clip': ['4', 1]},
    },
    '8': {
      'class_type': 'VAEDecode',
      'inputs': {'samples': ['3', 0], 'vae': ['4', 2]},
    },
    '9': {
      'class_type': 'SaveImage',
      'inputs': {'images': ['8', 0], 'filename_prefix': 'feiyu'},
    },
  };
}

/// Image-to-image: uploads the picture, re-encodes it and re-samples a bit.
Map<String, dynamic> defaultImg2Img(
  String ckptName, {
  int size = 512,
  int? steps,
  double? cfg,
  double denoise = 0.55,
}) {
  final fast = isFastCheckpoint(ckptName);
  return {
    '1': {
      'class_type': 'LoadImage',
      'inputs': {'image': ''},
    },
    '2': {
      'class_type': 'ImageScale',
      'inputs': {
        'upscale_method': 'lanczos',
        'width': size,
        'height': size,
        'crop': 'center',
        'image': ['1', 0],
      },
    },
    '3': {
      'class_type': 'VAEEncode',
      'inputs': {'pixels': ['2', 0], 'vae': ['4', 2]},
    },
    '4': {
      'class_type': 'CheckpointLoaderSimple',
      'inputs': {'ckpt_name': ckptName},
    },
    '5': {
      'class_type': 'CLIPTextEncode',
      'inputs': {'text': '', 'clip': ['4', 1]},
    },
    '6': {
      'class_type': 'CLIPTextEncode',
      'inputs': {'text': '', 'clip': ['4', 1]},
    },
    '7': {
      'class_type': 'KSampler',
      'inputs': {
        'seed': 1,
        'steps': steps ?? (fast ? 3 : 20),
        'cfg': cfg ?? (fast ? 1.0 : 7.0),
        'sampler_name': fast ? 'euler' : 'dpmpp_2m',
        'scheduler': fast ? 'normal' : 'karras',
        'denoise': denoise,
        'model': ['4', 0],
        'positive': ['5', 0],
        'negative': ['6', 0],
        'latent_image': ['3', 0],
      },
    },
    '8': {
      'class_type': 'VAEDecode',
      'inputs': {'samples': ['7', 0], 'vae': ['4', 2]},
    },
    '9': {
      'class_type': 'SaveImage',
      'inputs': {'images': ['8', 0], 'filename_prefix': 'feiyu_edit'},
    },
  };
}

/// Background removal: downscale (CPU runs it much faster), cut out, keep alpha.
Map<String, dynamic> defaultRemoveBg({int size = 512, String model = 'BiRefNet_512x512'}) {
  return {
    '1': {
      'class_type': 'LoadImage',
      'inputs': {'image': ''},
    },
    '2': {
      'class_type': 'ImageScale',
      'inputs': {
        'upscale_method': 'lanczos',
        'width': size,
        'height': size,
        'crop': 'center',
        'image': ['1', 0],
      },
    },
    '3': {
      'class_type': 'BiRefNetRMBG',
      'inputs': {'image': ['2', 0], 'model': model},
    },
    '4': {
      'class_type': 'JoinImageWithAlpha',
      'inputs': {'image': ['3', 0], 'alpha': ['3', 1]},
    },
    '5': {
      'class_type': 'SaveImage',
      'inputs': {'images': ['4', 0], 'filename_prefix': 'feiyu_cut'},
    },
  };
}

/// Puts the prompt into an exported workflow.
///
/// It finds the sampler, follows its `positive` link to a text-encode node and
/// replaces the text. Negative follows the `negative` link. Everything else is
/// left untouched, so LoRAs / ControlNet / custom samplers keep working.
Map<String, dynamic> patchWorkflow(
  Map<String, dynamic> workflow, {
  required String prompt,
  String negative = '',
  int? seed,
  String? imageName,
}) {
  final wf = jsonDecode(jsonEncode(workflow)) as Map<String, dynamic>;

  String? samplerId;
  for (final entry in wf.entries) {
    final node = entry.value;
    if (node is! Map) continue;
    final type = (node['class_type'] ?? '') as String;
    if (type.contains('KSampler') || type.contains('SamplerCustom')) {
      samplerId = entry.key;
      break;
    }
  }
  if (samplerId == null && prompt.trim().isNotEmpty) {
    throw Exception('这个工作流里找不到采样器（KSampler），请用「Save (API Format)」导出的完整工作流');
  }

  final sampler = samplerId == null ? null : wf[samplerId] as Map<String, dynamic>;
  final inputs = (sampler?['inputs'] ?? <String, dynamic>{}) as Map<String, dynamic>;

  void applyText(String key, String text) {
    if (text.isEmpty) return;
    final link = inputs[key];
    if (link is! List || link.isEmpty) return;
    final nodeId = link.first.toString();
    final target = wf[nodeId];
    if (target is! Map) return;
    final tInputs = target['inputs'];
    if (tInputs is Map) tInputs['text'] = text;
  }

  applyText('positive', prompt);
  applyText('negative', negative);

  // Feed the uploaded picture into the first LoadImage node.
  if (imageName != null && imageName.isNotEmpty) {
    var replaced = false;
    for (final node in wf.values) {
      if (node is! Map) continue;
      if ((node['class_type'] ?? '') != 'LoadImage') continue;
      final ni = node['inputs'];
      if (ni is Map) {
        ni['image'] = imageName;
        replaced = true;
      }
    }
    if (!replaced) {
      throw Exception('这个工作流的图片输入不是 LoadImage 节点，暂不支持');
    }
  }

  for (final node in wf.values) {
    if (node is! Map) continue;
    final ni = node['inputs'];
    if (ni is! Map) continue;
    if (ni.containsKey('seed') && seed != null) ni['seed'] = seed;
    if (ni.containsKey('noise_seed') && seed != null) ni['noise_seed'] = seed;
  }

  return wf;
}
