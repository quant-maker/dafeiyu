import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../ui/layout.dart';
import '../ui/surfaces.dart';
import '../ui/tokens.dart';
import 'comfy.dart';

/// A phone-sized console for the ComfyUI running on the desk computer.
class ComfyPage extends StatefulWidget {
  final String baseUrl;
  final String workflowJson;

  const ComfyPage({super.key, required this.baseUrl, required this.workflowJson});

  @override
  State<ComfyPage> createState() => _ComfyPageState();
}

class _ComfyPageState extends State<ComfyPage> {
  final _prompt = TextEditingController();
  final _negative = TextEditingController();

  bool _online = false;
  bool _checking = true;
  bool _busy = false;
  String? _error;
  int _queue = 0;
  String _stage = '';
  List<Uint8List> _results = const [];

  ComfyClient get _client => ComfyClient.resolved(widget.baseUrl, web: kIsWeb);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _prompt.dispose();
    _negative.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _checking = true);
    final online = await _client.ping();
    final queue = online ? await _client.queueLength() : 0;
    if (!mounted) return;
    setState(() {
      _online = online;
      _queue = queue;
      _checking = false;
    });
  }

  Map<String, dynamic>? _parseWorkflow() {
    if (widget.workflowJson.trim().isEmpty) return null;
    try {
      return jsonDecodeMap(widget.workflowJson);
    } catch (e) {
      setState(() => _error = '工作流 JSON 解析失败：$e');
      return null;
    }
  }

  Future<void> _generate() async {
    if (_busy) return;
    final text = _prompt.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '先写点提示词');
      return;
    }
    final wf = _parseWorkflow();
    if (wf == null) {
      setState(() => _error = '还没配置工作流：去设置 → ComfyUI 粘贴「Save (API Format)」的 JSON');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _stage = '提交…';
      _results = const [];
    });

    try {
      final patched = patchWorkflow(
        wf,
        prompt: text,
        negative: _negative.text.trim(),
        seed: DateTime.now().millisecondsSinceEpoch % 1000000007,
      );
      final id = await _client.submit(patched);
      if (mounted) setState(() => _stage = '排队中…');
      final images = await _client.waitForImages(
        id,
        onTick: (elapsed) {
          if (!mounted) return;
          setState(() => _stage = '生成中… ${elapsed.inSeconds}s');
        },
      );
      if (!mounted) return;
      setState(() {
        _results = images;
        _stage = '';
      });
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('ComfyUI'),
        actions: [
          GhostIconButton(
            icon: Icons.refresh,
            tooltip: '刷新状态',
            onPressed: _refresh,
          ),
        ],
      ),
      body: ContentFrame(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
          children: [
            _statusCard(),
            const SizedBox(height: AppSpacing.l),
            TextField(
              controller: _prompt,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: '提示词',
                hintText: '一只胖胖的小鲸鱼，坐在深夜窗边，暖色台灯…',
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _negative,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '反向提示词（可空）',
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: '生成',
                    loading: _busy,
                    onPressed: _busy || !_online ? null : _generate,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                TextButton(
                  onPressed: _online
                      ? () async {
                          await _client.clearQueue();
                          await _refresh();
                        }
                      : null,
                  child: const Text('清队列'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.m),
              InlineNotice(tone: NoticeTone.danger, message: _error!),
            ],
            if (_busy) ...[
              const SizedBox(height: AppSpacing.l),
              const LinearProgressIndicator(),
              if (_stage.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s),
                Text(
                  _stage,
                  style: AppType.caption.copyWith(color: AppPalette.text2),
                ),
              ],
            ],
            if (_results.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.l),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  if (constraints.maxWidth >= 600) {
                    return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1,
                      children: [
                        for (final bytes in _results)
                          _thumbnail(context, bytes),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < _results.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i == _results.length - 1 ? 0 : 12,
                          ),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _thumbnail(context, _results[i]),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _thumbnail(BuildContext context, Uint8List bytes) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.l),
      child: GestureDetector(
        onTap: () => _openFull(context, bytes),
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          semanticLabel: '生成结果',
        ),
      ),
    );
  }

  void _openFull(BuildContext context, Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: InteractiveViewer(child: Image.memory(bytes)),
      ),
    );
  }

  Widget _statusCard() {
    final Color color = _checking
        ? AppPalette.text3
        : _online
            ? AppPalette.mint
            : AppPalette.danger;
    final String label = _checking
        ? '检查连接…'
        : _online
            ? '已连接 · 队列 $_queue'
            : '连不上';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(color: AppPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusDot(color: color),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  label,
                  style: AppType.bodySmall.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.baseUrl,
            style: AppType.caption.copyWith(color: AppPalette.text3),
          ),
          if (!_checking && !_online) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '检查电脑上的 ComfyUI 是否开着、同一局域网',
              style: AppType.caption.copyWith(color: AppPalette.warm),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kept here so the page has no dependency on the app's settings code.
Map<String, dynamic> jsonDecodeMap(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  throw const FormatException('期望一个 JSON 对象');
}
