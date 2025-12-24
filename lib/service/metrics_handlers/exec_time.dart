import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../logger/logger.dart';

/// Класс для корректного измерения времени выполнения операций.
/// Разделяет измерения для синхронных и асинхронных операций,
/// а также для операций, блокирующих UI thread.
class ExecTime {
  final Logger logger;

  ExecTime({Logger? logger}) : logger = logger ?? getLogger('ExecTime');

  /// Измеряет время выполнения синхронной функции (pure computation time).
  /// Использует Stopwatch с микросекундами для высокой точности.
  T measureSyncExecutionTime<T>(T Function() task) {
    logger.fine('Starting sync execution time measurement');
    final sw = Stopwatch()..start();
    T result;
    try {
      result = task();
    } catch (e, st) {
      logger.severe('Task threw an exception', e, st);
      rethrow;
    } finally {
      sw.stop();
    }
    final microseconds = sw.elapsedMicroseconds;
    logger.info('Sync execution time: $microsecondsμs (${(microseconds / 1000).toStringAsFixed(2)}ms)');
    return result;
  }

  /// Измеряет время выполнения асинхронной функции.
  /// Для операций в isolate (compute) это измеряет только computation time,
  /// не блокируя UI thread.
  Future<T> measureAsyncExecutionTime<T>(Future<T> Function() task) async {
    logger.fine('Starting async execution time measurement');
    final sw = Stopwatch()..start();
    T result;
    try {
      result = await task();
    } catch (e, st) {
      logger.severe('Task threw an exception', e, st);
      rethrow;
    } finally {
      sw.stop();
    }
    final microseconds = sw.elapsedMicroseconds;
    logger.info('Async execution time: $microsecondsμs (${(microseconds / 1000).toStringAsFixed(2)}ms)');
    return result;
  }

  /// Измеряет время блокировки UI thread синхронной операцией.
  /// Использует Timeline для визуализации в DevTools и Stopwatch для точного измерения.
  /// 
  /// Важно: этот метод должен использоваться только для синхронных операций,
  /// которые выполняются на UI thread.
  Future<T> measureUIBlockingTime<T>(T Function() task, {String? label}) async {
    final measurementLabel = label ?? 'UI_BLOCKING_MEASUREMENT';
    logger.fine('Measuring UI blocking time, waiting for frame...');
    
    // Ждем завершения текущего кадра перед началом измерения
    await WidgetsBinding.instance.endOfFrame;
    
    // Используем Timeline для визуализации в DevTools
    developer.Timeline.startSync(measurementLabel);
    final sw = Stopwatch()..start();
    
    T result;
    try {
      result = task(); // UI BLOCK - синхронная операция
    } catch (e, st) {
      logger.severe('Task threw an exception during UI block', e, st);
      rethrow;
    } finally {
      sw.stop();
      developer.Timeline.finishSync();
    }
    
    // Ждем завершения следующего кадра после блокировки
    await WidgetsBinding.instance.endOfFrame;
    
    final microseconds = sw.elapsedMicroseconds;
    logger.info('UI blocking time: $microsecondsμs (${(microseconds / 1000).toStringAsFixed(2)}ms)');
    
    return result;
  }
}
