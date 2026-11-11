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
    id: 'gateway',
    name: 'AI Gateway（公司网关）',
    baseUrl: 'https://agent.oasis.mountainxplorer.ai/ai-gateway/openai/v1',
    models: ['jk/dsv4.1-flash', 'jk/kimi-k3'],
    note: '需内网或 VPN，手机可能连不上',
  ),
  ProviderPreset(
    id: 'deepseek',
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
    models: ['deepseek-v4.1-flash', 'deepseek-chat'],
    note: '便宜、中文好；flash 快，不能看图',
  ),
  ProviderPreset(
    id: 'moonshot',
    name: 'Kimi（月之暗面）',
    baseUrl: 'https://api.moonshot.cn/v1',
    models: ['kimi-k3', 'kimi-k2-0905-preview'],
    note: '上下文长；kimi 系支持看图',
  ),
  ProviderPreset(
    id: 'zhipu',
    name: '智谱 GLM',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    models: ['glm-5.3', 'glm-4-flash'],
    note: 'glm-5.3 支持看图',
  ),
  ProviderPreset(
    id: 'dashscope',
    name: '通义千问（阿里云）',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    models: ['qwen3.8-flash', 'qwen-plus', 'qwen-vl-max'],
    note: 'qwen-vl-max 看图，flash 最快',
  ),
  ProviderPreset(
    id: 'openai',
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    models: ['gpt-6.1-sol', 'gpt-4o-mini'],
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
