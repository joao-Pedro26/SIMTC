import 'package:flutter/material.dart';
import '../../tokens/colors.dart';

class SimtcLoading extends StatelessWidget {
  const SimtcLoading({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: SimtcColors.primary),
  );
}
