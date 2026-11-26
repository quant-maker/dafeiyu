import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../ui/image_save.dart';
import '../ui/layout.dart';
import '../ui/overlays.dart';
import '../ui/surfaces.dart';
import '../ui/tokens.dart';
import 'art_store.dart';
import 'comfy.dart';
import 'engine.dart';

/// A phone-sized console for the ComfyUI running on the desk computer.
class ComfyPage extends StatefulWidget {
  final String baseUrl;
  final String workflowJson;

  /// When provided, each result offers a "设为头像" action that hands the
  /// generated PNG bytes back to the host screen.
  final void Function(Uint8List bytes)? onUseAsAvatar;

  /// Opens Settings (ComfyUI section) and returns the saved values, so this
  /// page can pick up a workflow without being reopened.
  final Future<ComfyConfig?> Function()? onEditConfig;

  /// SD-Turbo's text encoder is English-only, so Chinese prompts have to be
  /// rewritten before they reach ComfyUI. Provided by the host screen (this
  /// page deliberately has no model settings of its own).
  final Future<String> Function(String text)? onTranslatePrompt;

  const ComfyPage({
    super.key,
    required this.baseUrl,
    required this.workflowJson,
    this.onUseAsAvatar,
    this.onEditConfig,
    this.onTranslatePrompt,
  });

  @override
  State<ComfyPage> createState() => _ComfyPageState();
}

class _ComfyPageState extends State<ComfyPage> {
  final _prompt = TextEditingController();
  final _negative = TextEditingController();

  late String _baseUrl;
  late String _workflowJson;

  bool _online = false;
  bool _checking = true;
  bool _busy = false;
  String? _error;
  int _queue = 0;
  String _stage = '';
  List<Uint8List> _results = const [];
  ArtStore? _art;

  ComfyEngineStatus _engine = const ComfyEngineStatus.unsupported();
  bool _engineBusy = false;
  String? _engineHint;

  static const List<String> _examples = <String>[
    '一只胖胖的小鲸鱼，坐在深夜窗边，暖色台灯',
    '雨夜的便利店门口，霓虹倒影',
    '毛绒质感的鲸鱼玩偶，柔光棚拍',
  ];

  ComfyClient get _client => ComfyClient.resolved(_baseUrl, web: kIsWeb);

  @override
  void initState() {
    super.initState();
    _baseUrl = widget.baseUrl;
    _workflowJson = widget.workflowJson;
    _loadArt();
    _refresh();
  }

  Future<void> _loadArt() async {
    try {
      final ArtStore store = await ArtStore.load();
      if (!mounted) return;
      setState(() => _art = store);
    } catch (_) {
      if (!mounted) return;
      setState(() => _art = ArtStore());
    }
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
    final engine = await ComfyEngine.health();
    if (!mounted) return;
    setState(() {
      _online = online;
      _queue = queue;
      _engine = engine;
      _checking = false;
    });
  }

  /// Start (or stop) the engine on the desktop, then wait until ComfyUI
  /// answers. Starting takes a while on CPU, so the hint counts down.
  Future<void> _toggleEngine() async {
    if (_engineBusy) return;
    final bool stopping = _online || _engine.running;
    setState(() {
      _engineBusy = true;
      _engineHint = stopping ? '正在停止 ComfyUI…' : '正在启动 ComfyUI…';
    });
    final String? err = stopping ? await ComfyEngine.stop() : await ComfyEngine.start();
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _engineBusy = false;
        _engineHint = err;
      });
      return;
    }
    if (stopping) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      setState(() {
        _engineBusy = false;
        _engineHint = '已停止';
      });
      await _refresh();
      return;
    }
    // Poll for up to a minute: the first start loads the model index.
    for (int i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      if (await _client.ping()) {
        setState(() {
          _engineBusy = false;
          _engineHint = '已启动';
        });
        await _refresh();
        return;
      }
      if (!mounted) return;
      setState(() => _engineHint = '正在启动 ComfyUI… ${(i + 1) * 3}s');
    }
    if (!mounted) return;
    setState(() {
      _engineBusy = false;
      _engineHint = '还没起来：看看桌面上的启动窗口有没有报错';
    });
    await _refresh();
  }

  Future<void> _openSettings() async {
    final fn = widget.onEditConfig;
    if (fn == null) return;
    final ComfyConfig? next = await fn();
    if (!mounted || next == null) return;
    setState(() {
      _baseUrl = next.baseUrl;
      _workflowJson = next.workflowJson;
      if (next.workflowJson.trim().isNotEmpty) _error = null;
      _engineHint = null;
    });
    await _refresh();
  }

  Map<String, dynamic>? _parseWorkflow() {
    if (_workflowJson.trim().isEmpty) return null;
    try {
      return jsonDecodeMap(_workflowJson);
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
      setState(() => _error = '还没配置工作流：点右上角的齿轮，或下面「去设置」');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _stage = '提交…';
      _results = const [];
    });

    try {
      String promptForModel = text;
      String negativeForModel = _negative.text.trim();
      final Future<String> Function(String)? translate = widget.onTranslatePrompt;
      if (translate != null) {
        if (mounted) setState(() => _stage = '整理提示词…');
        final String out = (await translate(text)).trim();
        if (out.isNotEmpty) promptForModel = out;
        if (negativeForModel.isNotEmpty) {
          final String negOut = (await translate(negativeForModel)).trim();
          if (negOut.isNotEmpty) negativeForModel = negOut;
        }
        if (mounted) setState(() => _stage = '提交…');
      }
      final patched = patchWorkflow(
        wf,
        prompt: promptForModel,
        negative: negativeForModel,
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
      await _persistArt(images, text);
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _persistArt(List<Uint8List> images, String prompt) async {
    if (images.isEmpty) return;
    final ArtStore store = _art ?? await ArtStore.load();
    if (!mounted) return;
    _art ??= store;
    final DateTime now = DateTime.now();
    final List<ArtItem> fresh = <ArtItem>[
      for (final Uint8List bytes in images)
        ArtItem(id: '', at: now, prompt: prompt, b64: base64Encode(bytes)),
    ];
    // addAll mutates the list synchronously, so the wall updates before the
    // save round-trip completes.
    final Future<void> pending = store.addAll(fresh);
    setState(() {});
    try {
      await pending;
    } catch (_) {
      if (!mounted) return;
      setState(() {});
      _showStorageNotice();
    }
  }

  void _showStorageNotice() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('存储空间不足，已清理最早的几张')),
      );
  }

  void _fillPrompt(String text) {
    setState(() {
      _prompt.text = text;
      _prompt.selection = TextSelection.collapsed(offset: text.length);
    });
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
          if (ComfyEngine.supported)
            GhostIconButton(
              icon: _online || _engine.running
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
              tooltip: _online || _engine.running
                  ? '停止本机的 ComfyUI'
                  : '启动本机的 ComfyUI',
              color: _online || _engine.running ? AppPalette.mint : null,
              onPressed: _engineBusy ? null : _toggleEngine,
            ),
          GhostIconButton(
            icon: Icons.settings_rounded,
            tooltip: 'ComfyUI 设置（工作流 / 地址）',
            onPressed: widget.onEditConfig == null ? null : _openSettings,
          ),
          GhostIconButton(
            icon: Icons.refresh,
            tooltip: '刷新状态',
            onPressed: _refresh,
          ),
          const SizedBox(width: AppSpacing.s),
        ],
      ),
      body: ContentFrame(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
          children: [
            _statusCard(),
            if (_workflowJson.trim().isEmpty) ...[
              const SizedBox(height: AppSpacing.m),
              _setupCard(),
            ],
            const SizedBox(height: AppSpacing.l),
            TextField(
              controller: _prompt,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: '提示词',
                hintText: '一只胖胖的小鲸鱼，坐在深夜窗边，暖色台灯…',
                helperText: '中文会自动翻成英文再画（这类模型的文本编码器只认英文）',
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
            const SizedBox(height: AppSpacing.xxl),
            _artSection(context),
          ],
        ),
      ),
    );
  }

  Widget _artSection(BuildContext context) {
    final List<ArtItem> items = _art?.items ?? const <ArtItem>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader(label: '作品'),
        const SizedBox(height: AppSpacing.m),
        if (items.isEmpty) _artEmpty(context) else _artGrid(context, items),
      ],
    );
  }

  Widget _artEmpty(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '还没有作品',
            style: AppType.subtitle.copyWith(color: AppPalette.text1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '点一句灵感，先生成第一张',
            style: AppType.caption.copyWith(color: AppPalette.text3),
          ),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: <Widget>[
              for (final String sample in _examples) _exampleChip(sample),
            ],
          ),
        ],
      ),
    );
  }

  Widget _exampleChip(String text) {
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _fillPrompt(text),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.s,
            ),
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadii.full),
              border: Border.all(
                color: AppPalette.primary.withValues(alpha: .30),
              ),
            ),
            child: Text(
              text,
              style: AppType.caption.copyWith(color: AppPalette.primary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _artGrid(BuildContext context, List<ArtItem> items) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap = AppSpacing.m;
        final int columns = constraints.maxWidth >= 520 ? 2 : 1;
        final double tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: tileWidth + 38,
          ),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) =>
              _artTile(context, items[index]),
        );
      },
    );
  }

  Widget _artTile(BuildContext context, ArtItem item) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.m),
        border: Border.all(color: AppPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              onTap: () => _openArt(context, item),
              child: Image.memory(
                item.bytes,
                fit: BoxFit.cover,
                semanticLabel: '作品',
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.s, right: 2),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption.copyWith(color: AppPalette.text3),
                    ),
                  ),
                  IconButton(
                    tooltip: '删除作品',
                    onPressed: () => _confirmRemove(item),
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    icon: Icon(Icons.close, color: AppPalette.text3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openArt(BuildContext context, ArtItem item) {
    showImageViewer(
      context,
      item.bytes,
      extraActions: _viewerActions(context, item.bytes),
    );
  }

  Future<void> _confirmRemove(ArtItem item) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('确认删除？'),
        content: const Text('这张作品会从画廊里移除。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final ArtStore? store = _art;
    if (store == null) return;
    final Future<void> pending = store.remove(item.id);
    setState(() {});
    try {
      await pending;
    } catch (_) {
      if (!mounted) return;
      setState(() {});
      _showStorageNotice();
    }
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

  Widget _setupCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppPalette.warm.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(color: AppPalette.warm.withValues(alpha: .30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.rule_folder_outlined, size: 18, color: AppPalette.warm),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  '还没有配置工作流',
                  style: AppType.subtitle.copyWith(color: AppPalette.text1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '在 ComfyUI 里用「Save (API Format)」导出 JSON，粘到设置 → ComfyUI；'
            '设置里也有一个内置的 SD-Turbo 示例可以先用起来。',
            style: AppType.caption.copyWith(color: AppPalette.text3),
          ),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: <Widget>[
              FilledButton.icon(
                key: const ValueKey('comfy-open-settings'),
                onPressed: widget.onEditConfig == null ? null : _openSettings,
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text('去设置'),
              ),
              if (ComfyEngine.supported && !(_online || _engine.running))
                OutlinedButton.icon(
                  key: const ValueKey('comfy-start-engine'),
                  onPressed: _engineBusy ? null : _toggleEngine,
                  icon: _engineBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.6),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('启动 ComfyUI'),
                ),
            ],
          ),
        ],
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
            _baseUrl,
            style: AppType.caption.copyWith(color: AppPalette.text3),
          ),
          if (!_checking && !_online) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              ComfyEngine.supported
                  ? '电脑上的 ComfyUI 没开。可以点右上角的 ▶ 或下面按钮直接启动。'
                  : '检查电脑上的 ComfyUI 是否开着、同一局域网',
              style: AppType.caption.copyWith(color: AppPalette.warm),
            ),
            if (ComfyEngine.supported) ...[
              const SizedBox(height: AppSpacing.s),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('comfy-status-start'),
                  onPressed: _engineBusy ? null : _toggleEngine,
                  icon: _engineBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.6),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('启动 ComfyUI'),
                ),
              ),
            ],
          ],
          if (_engineHint != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _engineHint!,
              style: AppType.caption.copyWith(color: AppPalette.text3),
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
