/// SD-Turbo (and most SD checkpoints) pair their noise predictor with an
/// English-only text encoder: encode a Chinese sentence and the conditioning
/// lands far outside the training distribution, so the sampler returns the
/// dataset mean — the "ink wash" picture owners see. Translate once, then
/// remember it: the same request usually repeats the same phrase.
class ImagePromptTranslator {
  ImagePromptTranslator({required this.translate});

  /// Turns a Chinese description into an English prompt. Throwing is fine:
  /// the raw text is used as a fallback.
  final Future<String> Function(String text) translate;

  final Map<String, String> _cache = <String, String>{};

  static final RegExp _cjk = RegExp(r'[\u3400-\u9fff]');

  /// Whether [text] contains characters the text encoder was never trained on.
  static bool needsEnglish(String text) => _cjk.hasMatch(text);

  Future<String> english(String raw) async {
    final String text = raw.trim();
    if (text.isEmpty || !needsEnglish(text)) return text;
    final String? hit = _cache[text];
    if (hit != null) return hit;
    try {
      final String out = await translate(text);
      final String clean = out
          .replaceAll(RegExp(r'[\r\n]+'), ' ')
          .replaceAll(RegExp(r'^["“”]+|["“”]+$'), '')
          .trim();
      if (clean.isEmpty || needsEnglish(clean)) return text;
      _cache[text] = clean;
      return clean;
    } catch (_) {
      return text;
    }
  }

  /// Only exposed for tests/diagnostics.
  int get cachedCount => _cache.length;
}
