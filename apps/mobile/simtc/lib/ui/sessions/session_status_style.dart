import 'package:flutter/widgets.dart';

import '../../data/models/training_session.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/widgets/status_chip.dart';

/// Como cada status de sessão aparece — o mesmo no card da Home e no
/// cabeçalho do detalhe, para o consultor reconhecer a sessão nas duas telas.
extension SessionStatusStyle on SessionStatus {
  StatusTone get tone => switch (this) {
        SessionStatus.planejado => StatusTone.neutral,
        SessionStatus.emAndamento => StatusTone.info,
        SessionStatus.concluido => StatusTone.success,
        SessionStatus.cancelado => StatusTone.danger,
      };

  IconData get icon => switch (this) {
        SessionStatus.planejado => AppIcons.pending,
        SessionStatus.emAndamento => AppIcons.inProgress,
        SessionStatus.concluido => AppIcons.approved,
        SessionStatus.cancelado => AppIcons.needsReview,
      };

  /// Traço superior do card da Home.
  Color get accentColor => switch (this) {
        SessionStatus.planejado => AppColors.border,
        SessionStatus.emAndamento => AppColors.primary,
        SessionStatus.concluido => AppColors.border,
        SessionStatus.cancelado => AppColors.dangerBorder,
      };
}
