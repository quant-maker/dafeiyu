/// Built-in ComfyUI workflows (API format), so drawing works before anyone
/// exports a JSON from the ComfyUI canvas.
///
/// Keep these in sync with `docs/comfyui.md` (model file names included): the
/// node ids are only a convenience, `patchWorkflow` rewires by class type.
library;

class ComfyWorkflowTemplate {
  const ComfyWorkflowTemplate({
    required this.id,
    required this.name,
    required this.note,
    required this.json,
  });

  final String id;
  final String name;

  /// One line for the settings picker: speed / hardware needs.
  final String note;
  final String json;
}

/// SD-Turbo: 4 steps, works on CPU (this machine runs `--cpu`). Two steps is
/// the model card's minimum, but at 512² it returns blob-shaped subjects; four
/// still lands inside the distilled range and actually draws the thing. Needs
/// `models/checkpoints/sd_turbo.safetensors`.
const kComfySdTurboWorkflow = r"""{
  "3": {"class_type": "KSampler", "inputs": {"seed": 1, "steps": 4, "cfg": 1.0, "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0, "model": ["4", 0], "positive": ["6", 0], "negative": ["7", 0], "latent_image": ["5", 0]}},
  "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_turbo.safetensors"}},
  "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 512, "height": 512, "batch_size": 1}},
  "6": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["4", 1]}},
  "7": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["4", 1]}},
  "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
  "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "feiyu"}}
}""";

/// Z-Image Turbo: 8 steps at CFG 1.0 with a zeroed negative, much better
/// quality but needs a GPU. Mirrors ComfyUI's own template; model files:
/// `diffusion_models/z_image_turbo_bf16.safetensors`,
/// `text_encoders/qwen_3_4b.safetensors`, `vae/ae.safetensors`.
const kComfyZImageTurboWorkflow = r"""{
  "3": {"class_type": "KSampler", "inputs": {"seed": 1, "steps": 8, "cfg": 1.0, "sampler_name": "res_multistep", "scheduler": "simple", "denoise": 1.0, "model": ["11", 0], "positive": ["27", 0], "negative": ["33", 0], "latent_image": ["13", 0]}},
  "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["29", 0]}},
  "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "feiyu"}},
  "11": {"class_type": "ModelSamplingAuraFlow", "inputs": {"shift": 3.0, "model": ["28", 0]}},
  "13": {"class_type": "EmptySD3LatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
  "27": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["30", 0]}},
  "28": {"class_type": "UNETLoader", "inputs": {"unet_name": "z_image_turbo_bf16.safetensors", "weight_dtype": "default"}},
  "29": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
  "30": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_4b.safetensors", "type": "lumina2", "device": "default"}},
  "33": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["27", 0]}}
}""";

const kComfyWorkflows = <ComfyWorkflowTemplate>[
  ComfyWorkflowTemplate(
    id: 'sd-turbo',
    name: 'SD-Turbo',
    note: '4 步，CPU 也能跑（默认）',
    json: kComfySdTurboWorkflow,
  ),
  ComfyWorkflowTemplate(
    id: 'z-image-turbo',
    name: 'Z-Image Turbo',
    note: '8 步，质量更好；需要显卡和 3 个模型文件（z_image_turbo_bf16 / qwen_3_4b / ae）',
    json: kComfyZImageTurboWorkflow,
  ),
];

ComfyWorkflowTemplate? comfyWorkflowTemplate(String id) {
  for (final t in kComfyWorkflows) {
    if (t.id == id) return t;
  }
  return null;
}

/// Which built-in matches [json] exactly, or null for a custom/edited workflow.
ComfyWorkflowTemplate? comfyWorkflowTemplateOf(String json) {
  for (final t in kComfyWorkflows) {
    if (t.json == json) return t;
  }
  return null;
}

/// The first SD-Turbo template shipped with two steps, which at 512² returns
/// blob-shaped subjects instead of the thing you asked for. Settings persist a
/// copy of the template, so owners who never edited it would otherwise keep the
/// old graph forever: upgrade that exact copy when it is read back.
final String _kComfySdTurboWorkflowV1 =
    kComfySdTurboWorkflow.replaceFirst('"steps": 4', '"steps": 2');

String comfyWorkflowUpgrade(String json) {
  if (json.trim() == _kComfySdTurboWorkflowV1.trim()) return kComfySdTurboWorkflow;
  return json;
}
