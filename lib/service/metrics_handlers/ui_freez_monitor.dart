import 'dart:async';

import 'package:flutter/material.dart';

/// Монитор для обнаружения UI фризов.
/// 
/// ВАЖНО: Этот класс использует приблизительный метод обнаружения фризов
/// через периодический таймер. Для точных измерений используйте FrameStatsCollector.
/// 
/// Этот монитор полезен для быстрого обнаружения длительных блокировок,
/// но сам Timer может влиять на производительность при частых проверках.
class UiFreezeMonitor {
  final Duration threshold;
  int? _lastTickMicroseconds;
  Timer? _timer;

  /// Создает монитор с заданным порогом обнаружения фризов.
  /// 
  /// [threshold] - минимальная длительность для считания фризом (по умолчанию 200ms).
  /// [checkInterval] - интервал проверки (по умолчанию 50ms, чтобы минимизировать влияние на производительность).
  UiFreezeMonitor({
    this.threshold = const Duration(milliseconds: 200),
    Duration? checkInterval,
  }) : _checkInterval = checkInterval ?? const Duration(milliseconds: 50);

  final Duration _checkInterval;

  void start() {
    // Используем Stopwatch для более точного измерения времени
    final stopwatch = Stopwatch()..start();
    _lastTickMicroseconds = stopwatch.elapsedMicroseconds;
    
    _timer = Timer.periodic(_checkInterval, (_) {
      final nowMicroseconds = stopwatch.elapsedMicroseconds;
      final diffMicroseconds = nowMicroseconds - _lastTickMicroseconds!;
      final diffMs = diffMicroseconds / 1000.0;

      // Проверяем, превышает ли интервал порог (учитывая интервал проверки)
      // Вычитаем интервал проверки, чтобы компенсировать задержку самого таймера
      final actualFreezeTime = diffMs - _checkInterval.inMilliseconds;
      
      if (actualFreezeTime > threshold.inMilliseconds) {
        debugPrint(
          '[Freeze] UI freeze detected: ${actualFreezeTime.toStringAsFixed(2)} ms '
          '(measured interval: ${diffMs.toStringAsFixed(2)} ms)',
        );
      }

      _lastTickMicroseconds = nowMicroseconds;
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _lastTickMicroseconds = null;
  }
}
