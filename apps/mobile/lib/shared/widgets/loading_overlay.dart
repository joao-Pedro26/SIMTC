import 'package:flutter/material.dart';
import '../../design_system/ds.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  const LoadingOverlay({required this.isLoading, required this.child, super.key});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      if (isLoading)
        Container(
          color: Colors.black12,
          child: const SimtcLoading(),
        ),
    ],
  );
}
