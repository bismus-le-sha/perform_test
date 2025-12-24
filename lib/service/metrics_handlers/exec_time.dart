import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../logger/logger.dart';

class ExecTime {
  final Logger logger;

  ExecTime({Logger? logger}) : logger = logger ?? getLogger('ExecTime');

  Future<int> measureExecutionTime(Future<void> Function() task) async {
    logger.fine('Starting execution time measurement');
    final sw = Stopwatch()..start();
    try {
      await task();
    } catch (e, st) {
      logger.severe('Task threw an exception', e, st);
      rethrow;
    } finally {
      sw.stop();
    }
    final ms = sw.elapsedMilliseconds;
    logger.info('Execution time: ${ms}ms');
    return ms;
  }

  Future<void> measureUIFreezTime(void Function() task) async {
    logger.fine('Measuring UI freeze time, waiting for frame...');
    await WidgetsBinding.instance.endOfFrame;
    final before = DateTime.now();

    try {
      task(); // UI BLOCK
    } catch (e, st) {
      logger.severe('Task threw an exception during UI block', e, st);
      rethrow;
    }

    await WidgetsBinding.instance.endOfFrame;
    final after = DateTime.now();

    final uiFreezeMs = after.difference(before).inMilliseconds;
    logger.info('UI freeze time: ${uiFreezeMs}ms');
  }
}
