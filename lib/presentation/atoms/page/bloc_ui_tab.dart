import 'package:flutter/material.dart';
import 'package:perform_test/presentation/atoms/widgets/kill.dart';
import 'package:perform_test/presentation/atoms/widgets/opacity.dart';

class BlocUITab extends StatelessWidget {
  const BlocUITab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(children: [KillWidget(), FadeSquare()]),
      ),
    );
  }
}
