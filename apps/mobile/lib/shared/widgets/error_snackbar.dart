import 'package:flutter/material.dart';
import '../../design_system/ds.dart';

void showErrorSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: SimtcTypography.body.copyWith(color: Colors.white)),
      backgroundColor: SimtcColors.noteM,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SimtcRadius.md)),
    ),
  );
}
