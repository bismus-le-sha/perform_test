import 'package:flutter/material.dart';
import 'package:perform_test/presentation/skeleton/placeholders.dart';
import 'package:perform_test/presentation/skeleton/shimmer.dart';
import 'package:perform_test/service/app_config/app_config.dart';
import 'package:perform_test/service/app_config/app_config_provider.dart';

const _shimmerGradient = LinearGradient(
  colors: [Color(0xFFEBEBF4), Color(0xFFF4F4F4), Color(0xFFEBEBF4)],
  stops: [0.1, 0.3, 0.4],
  begin: Alignment(-1.0, -0.3),
  end: Alignment(1.0, 0.3),
  tileMode: TileMode.clamp,
);

class SkeletonPlaceholder extends StatelessWidget {
  const SkeletonPlaceholder({super.key});

  final bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    final appConfig = AppConfigProvider.of(context);
    return Scaffold(
      body: Shimmer(
        linearGradient: _shimmerGradient,
        child: appConfig.get(FeatureToggle.minimizeExpensiveRendering)
            ? OptimPlaceHolderWay(isLoading: _isLoading)
            : BadPlaceHolderWay(isLoading: _isLoading),
      ),
    );
  }
}

class BadPlaceHolderWay extends StatelessWidget {
  const BadPlaceHolderWay({super.key, required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: isLoading ? const NeverScrollableScrollPhysics() : null,
      children: const [
        CustomShaderMask(child: ProfileHeaderPlaceholder()),
        CustomShaderMask(child: PhotoPlaceholder()),
        SizedBox(height: 8),
        CustomShaderMask(child: ProfileHeaderPlaceholder()),
        CustomShaderMask(child: PhotoPlaceholder()),
        SizedBox(height: 8),
        CustomShaderMask(child: ProfileHeaderPlaceholder()),
        CustomShaderMask(child: PhotoPlaceholder()),
      ],
    );
  }
}

class OptimPlaceHolderWay extends StatelessWidget {
  const OptimPlaceHolderWay({super.key, required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: isLoading ? const NeverScrollableScrollPhysics() : null,
      children: const [
        CustomShaderMask(
          child: Column(
            children: [CardPlaceholder(), CardPlaceholder(), CardPlaceholder()],
          ),
        ),
      ],
    );
  }
}
