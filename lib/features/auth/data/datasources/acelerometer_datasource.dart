import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/platform/platform_channels.dart';
import '../../domain/entities/step_data.dart';

/// DataSource para acelerómetro con Anti-Rebote para pasos
/// y Ventanas de Tiempo para estimación de estado.
///
/// Lógica completa en la capa de Datos (NO en Widgets):
/// - Debounce de 300ms: ignora vibraciones de un solo pisotón
/// - Ventana de 3s: crea un cojín temporal antes de cambiar estado
/// - Umbrales: caminar >13.0, correr >17.0, caída >35.0 m/s²
abstract class AccelerometerDataSource {
  Stream<StepData> get stepStream;
  Future<void> startCounting();
  Future<void> stopCounting();
  Future<bool> requestPermissions();
}

class AccelerometerDataSourceImpl implements AccelerometerDataSource {
  final EventChannel _eventChannel = const EventChannel(
    PlatformChannels.accelerometer
  );

  final MethodChannel _methodChannel = const MethodChannel(
    '${PlatformChannels.accelerometer}/control'
  );

  final StreamController<StepData> _controller =
      StreamController<StepData>.broadcast();
  StreamSubscription<dynamic>? _rawSubscription;

  int _stepCount = 0;
  bool _hasEverMoved = false;
  DateTime _lastStepTime = DateTime.now();
  DateTime _lastWalkTime = DateTime(2000);
  DateTime _lastRunTime = DateTime(2000);
  DateTime? _lastFallTime;
  static const int _fallCooldownSecs = 15;

  @override
  Stream<StepData> get stepStream => _controller.stream;

  @override
  Future<void> startCounting() async {
    await _rawSubscription?.cancel();

    _stepCount = 0;
    _hasEverMoved = false;
    _lastStepTime = DateTime.now();
    _lastWalkTime = DateTime(2000);
    _lastRunTime = DateTime(2000);

    await _methodChannel.invokeMethod('start');

    _rawSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) => _processReading((event as num).toDouble()),
      onError: (error) => debugPrint('[AccelDS] Error: $error'),
    );
  }

  void _processReading(double magnitude) {
    final now = DateTime.now();

    if (magnitude > 35.0) {
      if (_lastFallTime == null ||
          now.difference(_lastFallTime!).inSeconds >= _fallCooldownSecs) {
        _lastFallTime = now;
        _controller.add(StepData(
          stepCount: _stepCount,
          activityType: ActivityType.falling,
          magnitude: magnitude,
        ));
      }
      return;
    }

    if (magnitude > 13.0) {
      _hasEverMoved = true;
      if (magnitude > 17.0) {
        _lastRunTime = now;
      }
      _lastWalkTime = now;

      if (now.difference(_lastStepTime).inMilliseconds > 300) {
        _stepCount++;
        _lastStepTime = now;
      }
    }

    if (!_hasEverMoved) return;

    final activityType = _resolveState(now);

    _controller.add(StepData(
      stepCount: _stepCount,
      activityType: activityType,
      magnitude: magnitude,
    ));
  }

  ActivityType _resolveState(DateTime now) {
    if (now.difference(_lastRunTime).inSeconds < 3) {
      return ActivityType.running;
    }
    if (now.difference(_lastWalkTime).inSeconds < 3) {
      return ActivityType.walking;
    }
    return ActivityType.stationary;
  }

  @override
  Future<void> stopCounting() async {
    await _rawSubscription?.cancel();
    _rawSubscription = null;
    await _methodChannel.invokeMethod('stop');
  }

  @override
  Future<bool> requestPermissions() async {
    final a = await Permission.activityRecognition.request();
    final s = await Permission.sensors.request();
    return a.isGranted && s.isGranted;
  }

  void dispose() {
    _rawSubscription?.cancel();
    _controller.close();
  }
}
