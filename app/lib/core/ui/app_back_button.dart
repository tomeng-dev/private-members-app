import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Back button that pops when there is history, otherwise navigates to
/// [fallback]. Deep links (web URLs, notification taps) open pages with an
/// empty stack, so a plain [BackButton] would leave the user stranded.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallback = '/home', this.color});
  final String fallback;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return BackButton(color: color, onPressed: () => context.canPop() ? context.pop() : context.go(fallback));
  }
}
