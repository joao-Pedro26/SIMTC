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
  static const IconData back = Icons.chevron_left;
  static const IconData place = Icons.place_outlined;
  static const IconData event = Icons.event_outlined;
  static const IconData notes = Icons.sticky_note_2_outlined;
  static const IconData startSession = Icons.play_arrow_rounded;
  static const IconData assign = Icons.person_add_alt_1_outlined;

  /// Participante: pendente, em avaliação comigo e com outro consultor
  static const IconData notStarted = Icons.radio_button_unchecked;
  static const IconData evaluating = Icons.play_circle_outline;
  static const IconData lockedByOther = Icons.lock_outline;

  /// Checklist (Fase 4): cronômetro, acordeão e "Finalizar avaliação".
  static const IconData timer = Icons.timer_outlined;
  static const IconData expandMore = Icons.expand_more;
  static const IconData expandLess = Icons.expand_less;
  static const IconData finish = Icons.task_alt;

  /// Fila de envio (Fase 5A): o último envio falhou ("error" no canvas "2h").
  static const IconData sendFailed = Icons.error_outline;

  /// "Tentar novamente" de um item da fila (canvas "2h").
  static const IconData retry = Icons.refresh;

  /// "Iniciar avaliação" do checklist (Fase 5A — não está no canvas).
  static const IconData startEvaluation = Icons.play_arrow_rounded;

  /// Menu ⋮ do cabeçalho do checklist (Fase 5B — não está no canvas).
  static const IconData more = Icons.more_vert;

  /// Fechar o Resultado (canvas "2g").
  static const IconData close = Icons.close;
}
