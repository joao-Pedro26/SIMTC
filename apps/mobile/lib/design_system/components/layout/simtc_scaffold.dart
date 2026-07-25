import 'package:flutter/material.dart';
import '../../tokens/colors.dart';

class SimtcScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  const SimtcScaffold({
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SimtcColors.background,
    appBar: AppBar(
      title: Text(title),
      actions: actions,
      backgroundColor: SimtcColors.surface,
      elevation: 0,
      shadowColor: SimtcColors.border,
    ),
    body: body,
    floatingActionButton: floatingActionButton,
    bottomNavigationBar: bottomNavigationBar,
  );
}
