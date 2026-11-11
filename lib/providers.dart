/// Preset OpenAI-compatible providers, so switching vendors is one tap.
class ProviderPreset {
  final String id;
  final String name;
  final String baseUrl;
  final List<String> models;
  final String note;

  const ProviderPreset({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.models,
    this.note = '',
  });
}

const kProviders = <ProviderPreset>[
  ProviderPreset(
    id: 'deepseek',
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
    models: ['deepseek-chat', 'deepseek-reasoner'],
    note: '便宜、中文好；deepseek-chat 不能看图',
  ),
  ProviderPreset(
    id: 'moonshot',
    name: 'Kimi（月之暗面）',
    baseUrl: 'https://api.moonshot.cn/v1',
    models: ['kimi-k2-0905-preview', 'moonshot-v1-8k'],
    note: '上下文长；kimi 系支持看图',
  ),
  ProviderPreset(
    id: 'zhipu',
    name: '智谱 GLM',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    models: ['glm-4.5', 'glm-4-flash'],
    note: 'glm-4.5 支持看图，glm-4-flash 免费额度多',
  ),
  ProviderPreset(
    id: 'dashscope',
    name: '通义千问（阿里云）',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    models: ['qwen-plus', 'qwen-max', 'qwen-vl-max'],
    note: 'qwen-vl-max 看图，qwen-plus 日常',
  ),
  ProviderPreset(
    id: 'openai',
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    models: ['gpt-4o-mini', 'gpt-4o'],
    note: '需要海外网络',
  ),
  ProviderPreset(
    id: 'custom',
    name: '自定义',
    baseUrl: '',
    models: [],
    note: '填任意 OpenAI 兼容地址，例如自建网关',
  ),
];

ProviderPreset providerById(String id) =>
    kProviders.firstWhere((p) => p.id == id, orElse: () => kProviders.last);
