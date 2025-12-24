import 'package:flutter/foundation.dart';

class Calculate {
  int _calculate(int n) {
    if (n <= 1) {
      return n;
    }
    return _calculate(n - 1) + _calculate(n - 2);
  }

  Future<int> optimCalculateFibonacci(int numb) async =>
      await compute(_calculate, numb);

  Future<int> calculateFibonacci(int numb) async => _calculate(numb);
}
