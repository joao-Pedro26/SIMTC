import 'package:flutter/material.dart';

/// Ícones do app num ponto só.
///
/// O export do Claude Design usa Material Symbols Outlined; aqui usamos as
/// variantes equivalentes do Material Icons que já vêm com o Flutter. Trocar a
/// família depois (por exemplo, adotando um pacote de Material Symbols) é
/// mudança só deste arquivo.
abstract final class AppIcons {
  static const IconData email = Icons.mail_outlined;
  static const IconData password = Icons.lock_outlined;
  static const IconData showPassword = Icons.visibility_outlined;
  static const IconData hidePassword = Icons.visibility_off_outlined;
  static const IconData check = Icons.check;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData search = Icons.search;
  static const IconData offline = Icons.cloud_off_outlined;
  static const IconData noSignal = Icons.wifi_off_outlined;
  static const IconData sync = Icons.cloud_sync_outlined;
  static const IconData syncDone = Icons.cloud_done_outlined;
  static const IconData sessions = Icons.event_note_outlined;
  static const IconData profile = Icons.person_outlined;
  static const IconData approved = Icons.check_circle_outlined;
  static const IconData pending = Icons.schedule_outlined;
  static const IconData inProgress = Icons.hourglass_top_outlined;
  static const IconData needsReview = Icons.error_outline;
  static const IconData theoryOnly = Icons.menu_book_outlined;
  static const IconData logout = Icons.logout;
}
