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
  ArtStore? _art;

  static const List<String> _examples = <String>[
    '一只胖胖的小鲸鱼，坐在深夜窗边，暖色台灯',
    '雨夜的便利店门口，霓虹倒影',
    '毛绒质感的鲸鱼玩偶，柔光棚拍',
  ];

  ComfyClient get _client => ComfyClient.resolved(widget.baseUrl, web: kIsWeb);

  @override
  void initState() {
    super.initState();
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
