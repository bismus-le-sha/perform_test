import 'package:flutter/material.dart';
import 'package:perform_test/presentation/atoms/widgets/kill.dart';
import 'package:perform_test/presentation/atoms/widgets/opacity.dart';
import 'package:perform_test/service/app_config/widget/app_config_widgets.dart';

class BlocUITab extends StatelessWidget {
  const BlocUITab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppConfigBar(title: const Text('Bloc UI Page')),
      body: const Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(children: [KillWidget(), FadeSquare()]),
      ),
    );
  }
}
