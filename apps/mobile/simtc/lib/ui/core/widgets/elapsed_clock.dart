import 'dart:async';

import 'package:flutter/material.dart';

import '../date_labels.dart';

/// "00:12:41" que avança sozinho desde [start] — o cronômetro do rascunho na
/// linha "Avaliando · você" do detalhe da sessão (canvas "1e").
///
/// O tick redesenha só este texto, não a tela inteira.
class ElapsedClock extends StatefulWidget {
  const ElapsedClock({
    super.key,
    required this.start,
    this.clock,
    this.tickInterval = const Duration(seconds: 1),
    this.style,
  });

  final DateTime start;

  /// Relógio injetável para os testes; o padrão é `DateTime.now`.
  final DateTime Function()? clock;
  final Duration tickInterval;
  final TextStyle? style;

  @override
  State<ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<ElapsedClock> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(widget.tickInterval, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = (widget.clock ?? DateTime.now)();
    return Text(stopwatchLabel(now.difference(widget.start)), style: widget.style);
  }
}
