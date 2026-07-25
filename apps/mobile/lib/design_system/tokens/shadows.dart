import 'package:flutter/material.dart';

class SimtcShadows {
  SimtcShadows._();

  static const sm = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const md = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x05000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
}
