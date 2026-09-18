import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslateService {
  OnDeviceTranslator? _translator;
  TranslateLanguage? _sourceLang;
  TranslateLanguage? _targetLang;

  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();

  Future<void> downloadLanguageModel(TranslateLanguage language) async {
    await _modelManager.downloadModel(language.bcpCode);
  }

  Future<bool> isModelDownloaded(TranslateLanguage language) {
    return _modelManager.isModelDownloaded(language.bcpCode);
  }

  Future<void> deleteLanguageModel(TranslateLanguage language) async {
    await _modelManager.deleteModel(language.bcpCode);
  }

  void _ensureTranslator(TranslateLanguage source, TranslateLanguage target) {
    if (_sourceLang != source || _targetLang != target) {
      _translator?.close();
      _translator = OnDeviceTranslator(
        sourceLanguage: source,
        targetLanguage: target,
      );
      _sourceLang = source;
      _targetLang = target;
    }
  }

  Future<String> translate({
    required String text,
    required TranslateLanguage from,
    required TranslateLanguage to,
  }) async {
    _ensureTranslator(from, to);
    return _translator!.translateText(text);
  }

  void dispose() {
    _translator?.close();
  }
}
