/// Web build: there is no offline recogniser here (browsers route speech to a
/// remote service), so the cloud path stays in charge.
class LocalAsrImpl {
  static Future<LocalAsrImpl> create() async => LocalAsrImpl();

  Future<bool> get ready async => false;

  Future<void> download({void Function(double progress)? onProgress}) async {
    throw UnsupportedError('浏览器里没有离线语音识别，请使用云端转写');
  }

  Future<String?> transcribe(String wavPath) async => null;
}
