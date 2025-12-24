import 'package:logging/logging.dart';

/// Настройка глобального логгера приложения.
/// Вызывать один раз при старте приложения: configureGlobalLogging(level: Level.INFO);
void configureGlobalLogging({Level level = Level.INFO}) {
  Logger.root.level = level;
  Logger.root.onRecord.listen((record) {
    final buffer = StringBuffer()
      ..write('[${record.level.name}] ')
      ..write('${record.time.toIso8601String()} ')
      ..write('${record.loggerName}: ')
      ..write(record.message);
    if (record.error != null) buffer.write(' | error: ${record.error}');
    if (record.stackTrace != null) buffer.write('\n${record.stackTrace}');
    // Можно заменить на любой другой вывод (например, отправка на сервер)
    print(buffer.toString());
  });
}

/// Получить логгер с заданным именем (удобно для внедрения)
Logger getLogger(String name) => Logger(name);

/// Утилиты
Logger loggerFor(Object o) => Logger(o.runtimeType.toString());
