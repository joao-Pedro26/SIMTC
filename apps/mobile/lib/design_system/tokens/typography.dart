import 'package:flutter/material.dart';

class SimtcTypography {
  SimtcTypography._();
  static const fontFamily = 'Inter';

  static const headingLg = TextStyle(fontFamily: fontFamily, fontSize: 22, fontWeight: FontWeight.w700, height: 1.3);
  static const headingMd = TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w600, height: 1.4);
  static const headingSm = TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4);
  static const body      = TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static const bodyBold  = TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600, height: 1.5);
  static const caption   = TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w400, height: 1.4);
  static const label     = TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4);
}
