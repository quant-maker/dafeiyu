import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

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

  ComfyClient get _client => ComfyClient.resolved(widget.baseUrl);

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
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101A2C),
        title: const Text('ComfyUI'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: '刷新状态'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _statusCard(),
          const SizedBox(height: 14),
          TextField(
            controller: _prompt,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '提示词',
              hintText: '一只胖胖的小鲸鱼，坐在深夜窗边，暖色台灯…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _negative,
            decoration: const InputDecoration(
              labelText: '反向提示词（可空）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || !_online ? null : _generate,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_busy ? (_stage.isEmpty ? '生成中…' : _stage) : '生成'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
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
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF9A9A), fontSize: 12.5)),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 18),
            for (var i = 0; i < _results.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => _openFull(context, _results[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(_results[i], fit: BoxFit.contain),
                  ),
                ),
              ),
          ],
        ],
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
    final color = _checking
        ? Colors.white54
        : _online
            ? const Color(0xFF6BD08B)
            : const Color(0xFFFF8A8A);
    final label = _checking
        ? '检查连接…'
        : _online
            ? '已连接 · 队列 $_queue'
            : '连不上';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16223A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Row(
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: color)),
                const SizedBox(height: 2),
                Text(widget.baseUrl, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: .38))),
              ],
            ),
          ),
          if (!_checking && !_online)
            Text('检查电脑上的 ComfyUI 是否开着、同一局域网',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: .35))),
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
