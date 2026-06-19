import 'dart:async';
import 'package:flutter/material.dart';

class FallDetectionDialog extends StatefulWidget {
  final VoidCallback? onDismiss;

  const FallDetectionDialog({super.key, this.onDismiss});

  @override
  State<FallDetectionDialog> createState() => _FallDetectionDialogState();
}

class _FallDetectionDialogState extends State<FallDetectionDialog> {
  int _secondsLeft = 15;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Detección de caída'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _secondsLeft > 0
                  ? '¿Estás bien?'
                  : 'Por favor, responde. ¿Estás bien? Necesitamos confirmar que estás a salvo.',
              style: const TextStyle(fontSize: 18),
            ),
            if (_secondsLeft > 0) ...[
              const SizedBox(height: 16),
              Text(
                '$_secondsLeft',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              _timer?.cancel();
              widget.onDismiss?.call();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('Sí, estoy bien'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
