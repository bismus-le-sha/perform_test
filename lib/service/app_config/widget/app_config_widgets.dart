import 'package:flutter/material.dart';
import 'package:perform_test/core/config/feature_toggle.dart';
import 'package:perform_test/service/app_config/app_config_provider.dart';
import 'package:perform_test/service/app_config/page/app_config_page.dart';

class AppConfigToggle extends StatelessWidget {
  final FeatureToggle feature;
  const AppConfigToggle({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    final appConfig = AppConfigProvider.of(context);

    return AnimatedBuilder(
      animation: appConfig,
      builder: (context, _) {
        // ИСПРАВЛЕНО: используем appConfig из контекста, а не синглтон
        final value = appConfig.get(feature);
        return ListTile(
          title: Text(feature.name),
          trailing: Switch(
            value: value,
            // ИСПРАВЛЕНО: используем appConfig из контекста
            onChanged: (val) => appConfig.set(feature, val),
          ),
        );
      },
    );
  }
}

class AppConfigBar extends AppBar {
  AppConfigBar({
    super.key,
    required Text title,
    List<Widget>? actions,
    EdgeInsetsGeometry? actionsPadding,
  }) : super(
         title: title,
         actionsPadding: actionsPadding ?? const EdgeInsets.all(8),
         backgroundColor: const Color(0xFFFFB347),
         foregroundColor: Colors.white,
         actions: [
           if (actions != null) ...actions,
           Builder(
             builder: (context) => IconButton(
               onPressed: () => Navigator.of(context).push(
                 MaterialPageRoute(builder: (context) => const AppConfigPage()),
               ),
               icon: const Icon(Icons.settings),
             ),
           ),
         ],
       );
}
