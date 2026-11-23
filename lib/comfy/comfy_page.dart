import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../ui/image_save.dart';
import '../ui/layout.dart';
import '../ui/overlays.dart';
import '../ui/surfaces.dart';
import '../ui/tokens.dart';
import 'comfy.dart';

/// A phone-sized console for the ComfyUI running on the desk computer.
class ComfyPage extends StatefulWidget {
  final String baseUrl;
  final String workflowJson;

  /// When provided, each result offers a "设为头像" action that hands the
  /// generated PNG bytes back to the host screen.
  final void Function(Uint8List bytes)? onUseAsAvatar;

  const ComfyPage({
    super.key,
    required this.baseUrl,
    required this.workflowJson,
    this.onUseAsAvatar,
  });

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
                          _resultTile(context, bytes, grid: true),
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
                          child: _resultTile(
                            context,
                            _results[i],
                            grid: false,
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

  Widget _resultTile(
    BuildContext context,
    Uint8List bytes, {
    required bool grid,
  }) {
    final Widget image = ClipRRect(
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
    return Column(
      mainAxisSize: grid ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (grid)
          Expanded(child: SizedBox.expand(child: image))
        else
          AspectRatio(aspectRatio: 1, child: image),
        _actionRow(context, bytes),
      ],
    );
  }

  Widget _actionRow(BuildContext context, Uint8List bytes) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.s,
        children: [
          TextButton(
            onPressed: () => _save(context, bytes),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('保存'),
          ),
          if (widget.onUseAsAvatar != null)
            TextButton(
              onPressed: () => _useAsAvatar(context, bytes),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('设为头像'),
            ),
        ],
      ),
    );
  }

  List<Widget> _viewerActions(BuildContext context, Uint8List bytes) {
    return <Widget>[
      TextButton(
        onPressed: () => _save(context, bytes),
        child: const Text('保存', style: TextStyle(color: Colors.white)),
      ),
      if (widget.onUseAsAvatar != null)
        TextButton(
          onPressed: () {
            _useAsAvatar(context, bytes);
            Navigator.of(context).pop();
          },
          child: const Text('设为头像', style: TextStyle(color: Colors.white)),
        ),
    ];
  }

  Future<void> _save(BuildContext context, Uint8List bytes) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final String? path = await saveImageBytes(bytes);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(kIsWeb ? '已开始下载' : '已保存：$path'),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  void _useAsAvatar(BuildContext context, Uint8List bytes) {
    widget.onUseAsAvatar!(bytes);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已设为她的头像')));
  }

  void _openFull(BuildContext context, Uint8List bytes) {
    showImageViewer(
      context,
      bytes,
      extraActions: _viewerActions(context, bytes),
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
