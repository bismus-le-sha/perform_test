import 'package:flutter/foundation.dart';

/// Класс для вычисления чисел Фибоначчи.
/// Демонстрирует разницу между синхронным и изолированным вычислением.
class Calculate {
  int _calculate(int n) {
    if (n <= 1) {
      return n;
    }
    return _calculate(n - 1) + _calculate(n - 2);
  }

  /// Оптимизированная версия: вычисление в изоляте (не блокирует UI поток).
  /// Возвращает Future, так как compute работает асинхронно.
  Future<int> optimCalculateFibonacci(int numb) async =>
      await compute(_calculate, numb);

  /// Синхронная версия: вычисление в UI потоке (блокирует интерфейс).
  /// Используется для измерения UI blocking time.
  int calculateFibonacciSync(int numb) => _calculate(numb);

  /// Асинхронная обертка для обратной совместимости.
  /// ВАЖНО: Для измерения UI blocking используйте calculateFibonacciSync.
  @Deprecated('Use calculateFibonacciSync for UI blocking measurements')
  Future<int> calculateFibonacci(int numb) async => _calculate(numb);
}
