/// Web stub: no on-device synthesis here.
class LocalTtsImpl {
  static Future<LocalTtsImpl> create() async => LocalTtsImpl();

  /// Kept in sync with the native implementation so the UI can list voices.
  static const voices = <int, String>{
    45: '小贝（女）',
    46: '小妮（女）',
    47: '小小（女）',
    48: '小艺（女）',
    49: '云间（男）',
    50: '云希（男）',
    51: '云夏（男）',
    52: '云扬（男）',
  };

  Future<bool> get ready async => false;

  Future<void> download({void Function(double progress)? onProgress}) async {
    throw UnsupportedError('浏览器里没有端侧语音合成');
  }

  Future<bool> speak(
    String text, {
    int sid = 47,
    double speed = 1.0,
    bool awaitCompletion = false,
  }) async => false;

  Future<void> stop() async {}
}
