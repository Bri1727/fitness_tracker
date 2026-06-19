import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/services/activity_service.dart';
import '../../../../core/services/fall_detection_service.dart';
import 'fall_detection_dialog.dart';

class ActivityMonitorWidget extends StatefulWidget {
  final Widget child;

  const ActivityMonitorWidget({super.key, required this.child});

  @override
  State<ActivityMonitorWidget> createState() => _ActivityMonitorWidgetState();
}

class _ActivityMonitorWidgetState extends State<ActivityMonitorWidget> {
  final TtsService _tts = TtsService();
  final ActivityService _activityService = ActivityService();
  final FallDetectionService _fallService = FallDetectionService();

  StreamSubscription<ActivityEventData>? _activitySub;
  StreamSubscription<void>? _fallSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final permsGranted = await _requestPermissions();
    debugPrint('[Monitor] Permissions granted: $permsGranted');

    await _tts.init();
    final ttsOk = await _tts.test();
    debugPrint('[Monitor] TTS test result: $ttsOk');

    if (ttsOk) {
      await _tts.speak('Iniciando monitoreo de actividad');
    }

    if (permsGranted) {
      await _activityService.start();
      await _fallService.start();
    }

    _activitySub = _activityService.activityStream.listen((event) {
      final message = _activityService.getMessageForActivity(event.activity);
      debugPrint('[Monitor] Activity event: ${event.activity} -> "$message"');
      if (ttsOk) {
        _tts.speak(message);
      } else {
        debugPrint('[Monitor] TTS not available, skipping speech');
      }
    });

    _fallSub = _fallService.fallStream.listen((_) {
      if (ttsOk) {
        _tts.speak('Se ha detectado una caída, ¿Te encuentras bien?');
      }
      _showFallDialog();
    });
  }

  Future<bool> _requestPermissions() async {
    if (await Permission.activityRecognition.isGranted &&
        await Permission.sensors.isGranted) {
      return true;
    }

    final activityStatus = await Permission.activityRecognition.request();
    final sensorsStatus = await Permission.sensors.request();

    return activityStatus.isGranted && sensorsStatus.isGranted;
  }

  void _showFallDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FallDetectionDialog(),
    );
  }

  @override
  void dispose() {
    _activitySub?.cancel();
    _fallSub?.cancel();
    _activityService.dispose();
    _fallService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
