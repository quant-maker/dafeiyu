/// Web build: there is no offline recogniser here (browsers route speech to a
/// remote service), so the cloud path stays in charge.
class LocalAsrImpl {
  static Future<LocalAsrImpl> create({String kind = 'dolphin'}) async => LocalAsrImpl();

  static const models = <String, String>{
    'dolphin': 'Dolphin 2025（99 MB，快）',
    'sensevoice': 'SenseVoice（228 MB，方言更强）',
  };

  Future<bool> get ready async => false;

  Future<void> download({void Function(double progress)? onProgress}) async {
    throw UnsupportedError('浏览器里没有离线语音识别，请使用云端转写');
  }

  Future<String?> transcribe(String wavPath) async => null;
}
