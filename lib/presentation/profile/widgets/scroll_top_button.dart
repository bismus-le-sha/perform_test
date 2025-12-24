import 'package:flutter/material.dart';

class BadScrollToTopButton extends StatefulWidget {
  final ScrollController scrollController;

  const BadScrollToTopButton({super.key, required this.scrollController});

  @override
  State<BadScrollToTopButton> createState() => _BadScrollToTopButtonState();
}

class _BadScrollToTopButtonState extends State<BadScrollToTopButton> {
  bool _showScrollingToTopButton = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    setState(() {
      _showScrollingToTopButton = widget.scrollController.offset > 100;
    });
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Bad Button build');
    return _showScrollingToTopButton
        ? FloatingActionButton(
            onPressed: () {
              widget.scrollController.animateTo(
                0.0,
                curve: Curves.easeIn,
                duration: const Duration(milliseconds: 300),
              );
            },
            child: const Icon(Icons.arrow_upward),
          )
        : const SizedBox.shrink();
  }
}

class OptimScrollToTopButton extends StatefulWidget {
  final ScrollController scrollController;

  const OptimScrollToTopButton({super.key, required this.scrollController});

  @override
  State<OptimScrollToTopButton> createState() => _OptimScrollToTopButton();
}

class _OptimScrollToTopButton extends State<OptimScrollToTopButton> {
  bool _showScrollingToTopButton = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    bool showScrollingToTopButton = widget.scrollController.offset > 100;
    if (showScrollingToTopButton != _showScrollingToTopButton) {
      setState(() {
        _showScrollingToTopButton = showScrollingToTopButton;
      });
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Optim Button build');
    return _showScrollingToTopButton
        ? FloatingActionButton(
            onPressed: () {
              widget.scrollController.animateTo(
                0.0,
                curve: Curves.easeIn,
                duration: const Duration(milliseconds: 300),
              );
            },
            child: const Icon(Icons.arrow_upward),
          )
        : const SizedBox.shrink();
  }
}
