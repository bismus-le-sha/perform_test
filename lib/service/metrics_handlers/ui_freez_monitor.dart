import 'dart:async';

import 'package:flutter/material.dart';

class UiFreezeMonitor {
  final Duration threshold;
  DateTime? _lastTick;
  Timer? _timer;

  UiFreezeMonitor({this.threshold = const Duration(milliseconds: 200)});

  void start() {
    _lastTick = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = DateTime.now();
      final diff = now.difference(_lastTick!);

      if (diff > threshold) {
        debugPrint('[Freeze] Freeze detected: ${diff.inMilliseconds} ms');
      }

      _lastTick = now;
    });
  }

  void stop() {
    _timer?.cancel();
  }
}
