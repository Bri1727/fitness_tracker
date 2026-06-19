import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../features/auth/domain/entities/step_data.dart';

class VoiceAnnouncer {
  final FlutterTts _flutterTts = FlutterTts();
  ActivityType? _lastAnnouncedState;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      final candidates = <String>['es-ES', 'es-MX', 'en-US', 'en-GB'];
      String selectedLang = candidates.first;

      try {
        final defaultVoice = await _flutterTts.getDefaultVoice;
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
          await _flutterTts.setLanguage(lang);
          langSet = true;
          selectedLang = lang;
          break;
        } catch (_) {}
      }

      if (!langSet) {
        debugPrint('[VoiceAnnouncer] init FAILED: no language available');
        return;
      }

      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _initialized = true;
      debugPrint('[VoiceAnnouncer] initialized with $selectedLang');
    } catch (e) {
      debugPrint('[VoiceAnnouncer] init error: $e');
    }
  }

  Future<void> announceActivityChange(ActivityType newState) async {
    if (_lastAnnouncedState == newState) return;

    _lastAnnouncedState = newState;

    if (!_initialized) await init();
    if (!_initialized) return;

    final message = _toSpanish(newState);
    if (message == null) return;

    try {
      await _flutterTts.stop();
      await _flutterTts.speak(message);
      debugPrint('[VoiceAnnouncer] spoke: "$message"');
    } catch (e) {
      debugPrint('[VoiceAnnouncer] speak error: $e');
    }
  }

  String? _toSpanish(ActivityType type) {
    switch (type) {
      case ActivityType.walking:
        return 'Estás caminando';
      case ActivityType.running:
        return 'Estás corriendo';
      case ActivityType.stationary:
        return 'Te has detenido';
      default:
        return null;
    }
  }
}
