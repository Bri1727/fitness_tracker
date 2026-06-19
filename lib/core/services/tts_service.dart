import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      final candidates = <String>['es-ES', 'es-MX', 'en-US', 'en-GB'];
      String selectedLang = candidates.first;

      try {
        final defaultVoice = await _tts.getDefaultVoice;
        if (defaultVoice != null &&
            defaultVoice is Map &&
            defaultVoice.containsKey('locale')) {
          final deviceLocale = defaultVoice['locale'];
          if (deviceLocale != null &&
              deviceLocale is String &&
              (deviceLocale.startsWith('es') ||
                  deviceLocale.startsWith('en'))) {
            selectedLang = deviceLocale;
          }
        }
      } catch (_) {}

      candidates
        ..remove(selectedLang)
        ..insert(0, selectedLang);

      bool langSet = false;
      for (final lang in candidates) {
        try {
          await _tts.setLanguage(lang);
          langSet = true;
          selectedLang = lang;
          debugPrint('TTS setLanguage OK: $lang');
          break;
        } catch (e) {
          debugPrint('TTS setLanguage failed for $lang: $e');
        }
      }

      if (!langSet) {
        debugPrint('TTS init FAILED: no language worked');
        _initialized = false;
        return;
      }

      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _initialized = true;
      debugPrint('TTS initialized with language: $selectedLang');
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  /// Returns true if TTS is initialized and ready to speak.
  bool get isInitialized => _initialized;

  Future<bool> test() async {
    if (!_initialized) await init();
    if (!_initialized) return false;
    try {
      await _tts.stop();
      await _tts.speak('ok');
      return true;
    } catch (e) {
      debugPrint('TTS test failed: $e');
      return false;
    }
  }

  Future<void> speak(String message) async {
    try {
      if (!_initialized) await init();
      if (!_initialized) {
        debugPrint('TTS speak SKIP: not initialized, message="$message"');
        return;
      }
      await _tts.stop();
      await _tts.speak(message);
      debugPrint('TTS spoke: "$message"');
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }
}
