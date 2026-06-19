import 'dart:async';
import 'package:activity_recognition_flutter/activity_recognition_flutter.dart';
import 'package:flutter/foundation.dart';

enum DetectedActivity { stationary, walking, running, unknown }

class ActivityEventData {
  final DetectedActivity activity;
  final int confidence;

  const ActivityEventData({
    required this.activity,
    required this.confidence,
  });
}

class ActivityService {
  final ActivityRecognition _activityRecognition = ActivityRecognition();

  StreamSubscription<ActivityEvent>? _subscription;
  Timer? _confirmTimer;

  DetectedActivity _lastAnnounced = DetectedActivity.unknown;
  DetectedActivity _confirmingType = DetectedActivity.unknown;
  int _confirmingCount = 0;
  bool _hasAnnounced = false;

  final int requiredConsecutive = 2;
  final int confirmTimeoutSeconds = 20;
  final int minConfidence = 40;

  final StreamController<ActivityEventData> _controller =
      StreamController<ActivityEventData>.broadcast();

  Stream<ActivityEventData> get activityStream => _controller.stream;

  DetectedActivity get lastAnnounced => _lastAnnounced;

  Future<void> start() async {
    try {
      _subscription = _activityRecognition
          .activityStream(runForegroundService: true)
          .listen(_onActivityEvent, onError: _onError);

      debugPrint('[ActivityService] Stream started');
    } catch (e) {
      debugPrint('[ActivityService] Start error: $e');
    }
  }

  void _onActivityEvent(ActivityEvent event) {
    final rawType = event.type;
    final confidence = event.confidence;
    final mapped = _mapActivityType(rawType);

    debugPrint(
        '[ActivityService] EVENT: raw=$rawType conf=$confidence% mapped=$mapped last=$_lastAnnounced confirming=$_confirmingType($_confirmingCount)');

    if (confidence < minConfidence) {
      debugPrint('[ActivityService] SKIP low confidence');
      return;
    }

    if (mapped == _lastAnnounced) {
      debugPrint('[ActivityService] BACK to last announced — reset confirm');
      _resetConfirm();
      return;
    }

    if (mapped == _confirmingType) {
      _confirmingCount++;
      debugPrint('[ActivityService] CONFIRMING $mapped x$_confirmingCount');

      if (_confirmingCount >= requiredConsecutive) {
        _confirmTimer?.cancel();
        _confirmTimer = null;

        if (!_hasAnnounced && mapped == DetectedActivity.stationary) {
          debugPrint('[ActivityService] CONFIRMED (first, stationary — silent)');
          _lastAnnounced = mapped;
          _hasAnnounced = true;
        } else {
          _lastAnnounced = mapped;
          _hasAnnounced = true;
          debugPrint('[ActivityService] CONFIRMED ($mapped)');
          _controller.add(ActivityEventData(
            activity: mapped,
            confidence: confidence,
          ));
        }

        _confirmingType = DetectedActivity.unknown;
        _confirmingCount = 0;
      }
      return;
    }

    debugPrint(
        '[ActivityService] NEW confirming=$mapped (was $_confirmingType)');
    _confirmingType = mapped;
    _confirmingCount = 1;
    _confirmTimer?.cancel();
    _confirmTimer = Timer(Duration(seconds: confirmTimeoutSeconds), () {
      debugPrint(
          '[ActivityService] TIMEOUT confirming=$_confirmingType count=$_confirmingCount');
      _confirmTimer = null;
      _confirmingType = DetectedActivity.unknown;
      _confirmingCount = 0;
    });
  }

  void _resetConfirm() {
    _confirmTimer?.cancel();
    _confirmTimer = null;
    _confirmingType = DetectedActivity.unknown;
    _confirmingCount = 0;
  }

  void _onError(Object error) {
    debugPrint('[ActivityService] Error: $error');
  }

  DetectedActivity _mapActivityType(ActivityType type) {
    switch (type) {
      case ActivityType.WALKING:
      case ActivityType.ON_FOOT:
        return DetectedActivity.walking;
      case ActivityType.RUNNING:
        return DetectedActivity.running;
      case ActivityType.STILL:
      case ActivityType.TILTING:
      case ActivityType.UNKNOWN:
        return DetectedActivity.stationary;
      default:
        return DetectedActivity.unknown;
    }
  }

  String getMessageForActivity(DetectedActivity activity) {
    switch (activity) {
      case DetectedActivity.walking:
        return 'Estás caminando';
      case DetectedActivity.running:
        return 'Estás corriendo';
      case DetectedActivity.stationary:
        return 'Te has detenido';
      case DetectedActivity.unknown:
        return 'Estado desconocido';
    }
  }

  Future<void> stop() async {
    _confirmTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
