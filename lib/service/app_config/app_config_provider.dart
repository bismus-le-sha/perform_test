import 'package:flutter/material.dart';
import 'app_config.dart';

class AppConfigProvider extends InheritedNotifier<AppConfig> {
  const AppConfigProvider({
    super.key,
    required AppConfig super.notifier,
    required super.child,
  });

  static AppConfig of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<AppConfigProvider>();
    assert(provider != null, 'AppConfigProvider not found in context');
    return provider!.notifier!;
  }
}
