import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class FallDetectionService {
  StreamSubscription<AccelerometerEvent>? _subscription;
  final _controller = StreamController<void>.broadcast();
  DateTime? _lastFallAlert;
  final int _cooldownSeconds = 15;

  final double fallThreshold = 35.0;

  Stream<void> get fallStream => _controller.stream;

  Future<void> start() async {
    _subscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onSensorEvent);
  }

  void _onSensorEvent(AccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (magnitude > fallThreshold) {
      final now = DateTime.now();
      if (_lastFallAlert == null ||
          now.difference(_lastFallAlert!).inSeconds >= _cooldownSeconds) {
        _lastFallAlert = now;
        _controller.add(null);
      }
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
