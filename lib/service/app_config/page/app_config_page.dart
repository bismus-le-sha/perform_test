import 'package:flutter/material.dart';
import 'package:perform_test/service/app_config/app_config.dart';
import 'package:perform_test/service/app_config/widget/app_config_widgets.dart';

class AppConfigPage extends StatelessWidget {
  const AppConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('App config')),
      body: ListView.builder(
        itemCount: FeatureToggle.values.length,
        itemBuilder: (context, index) =>
            AppConfigToggle(feature: FeatureToggle.values[index]),
      ),
    );
  }
}
