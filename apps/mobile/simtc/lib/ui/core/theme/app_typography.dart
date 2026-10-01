import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Escala tipográfica do app, sobre as fontes variáveis embutidas em
/// `assets/fonts` (Inter para texto, JetBrains Mono para números/contadores).
///
/// Como as fontes são variáveis, cada estilo define `fontWeight` (para o
/// Flutter escolher a métrica) e `fontVariations` com o eixo `wght` (para o
/// peso ser interpolado de verdade, em vez de simulado).
abstract final class AppTypography {
  static const String interFamily = 'Inter';
  static const String monoFamily = 'JetBrainsMono';

  static TextStyle _inter({
    required double size,
    required FontWeight weight,
    required double height,
    Color color = AppColors.text,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: interFamily,
      fontSize: size,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
    );
  }

  static TextStyle _mono({
    required double size,
    required FontWeight weight,
    required double height,
    Color color = AppColors.text,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
    );
  }

  /// Título de tela ("Minhas sessões")
  static TextStyle get screenTitle =>
      _inter(size: 22, weight: FontWeight.w700, height: 1.2, letterSpacing: -0.22);

  /// Linha abaixo do título de uma aba ("Última sincronização hoje 07:12")
  static TextStyle get screenSubtitle =>
      _inter(size: 13, weight: FontWeight.w400, height: 1.2, color: AppColors.text3);

  /// Título do cartão âmbar da fila sem rede ("3 avaliações na fila")
  static TextStyle get queueNoticeTitle =>
      _inter(size: 16, weight: FontWeight.w600, height: 1.25, color: AppColors.noteCommentInk);

  /// Título da Home ("Minhas sessões" / "Sessões") — maior que o
  /// `screenTitle`, ajustado no aparelho em 24/09/2026.
  static TextStyle get homeTitle =>
      _inter(size: 24, weight: FontWeight.w700, height: 1.2, letterSpacing: -0.22);

  /// Saudação acima do título da Home ("Bom dia, Carla") — ajustada no
  /// aparelho em 24/09/2026.
  static TextStyle get homeGreeting =>
      _inter(size: 14, weight: FontWeight.w400, height: 1.45, color: AppColors.text2);

  /// Título de barra superior em fluxo empilhado ("Detalhe da sessão")
  static TextStyle get appBarTitle =>
      _inter(size: 17, weight: FontWeight.w600, height: 1.25);

  /// Título de item de lista (nome da empresa, nome do participante)
  static TextStyle get cardTitle =>
      _inter(size: 16, weight: FontWeight.w600, height: 1.3);

  /// Nome da empresa no cabeçalho do detalhe da sessão
  static TextStyle get detailTitle =>
      _inter(size: 18, weight: FontWeight.w600, height: 1.25);

  /// Iniciais da empresa no lugar do logo (card da Home, detalhe da sessão)
  static TextStyle get logoInitials =>
      _inter(size: 14, weight: FontWeight.w700, height: 1, color: AppColors.primaryDark);

  /// Texto padrão
  static TextStyle get body =>
      _inter(size: 13.5, weight: FontWeight.w400, height: 1.35, color: AppColors.text3);

  /// Texto de apoio em blocos de aviso
  static TextStyle get bodySmall =>
      _inter(size: 13, weight: FontWeight.w400, height: 1.45, color: AppColors.text2);

  /// Metadados de item (data, local, CPF)
  static TextStyle get meta =>
      _inter(size: 12.5, weight: FontWeight.w400, height: 1.3, color: AppColors.text3);

  /// Cabeçalho de seção de lista ("Hoje · 23 set", "Concluídas")
  static TextStyle get sectionTitle =>
      _inter(size: 13, weight: FontWeight.w700, height: 1.3, color: AppColors.text3);

  /// Rótulo de campo de formulário
  static TextStyle get fieldLabel =>
      _inter(size: 12.5, weight: FontWeight.w600, height: 1.2, color: AppColors.text3);

  /// Texto digitado em campo
  static TextStyle get fieldValue =>
      _inter(size: 16, weight: FontWeight.w400, height: 1.3);

  /// Rótulo de chip (status, severidade, filtro)
  static TextStyle get chipLabel =>
      _inter(size: 12, weight: FontWeight.w600, height: 1.2);

  /// Rótulo de opção ao lado de um controle (checkbox, rádio)
  static TextStyle get optionLabel =>
      _inter(size: 14, weight: FontWeight.w400, height: 1.2, color: AppColors.text2);

  /// Rótulo de item da navbar
  static TextStyle get navLabel =>
      _inter(size: 10, weight: FontWeight.w600, height: 1);

  /// Número do badge da fila no indicador do cabeçalho (canvas "2c")
  static TextStyle get headerBadge =>
      _inter(size: 9, weight: FontWeight.w700, height: 1, color: AppColors.surface);

  /// Texto de botão principal
  static TextStyle get button =>
      _inter(size: 16, weight: FontWeight.w700, height: 1.2, color: AppColors.surface);

  /// Texto de botão compacto, dentro de uma linha de lista ("Atribuir a mim")
  static TextStyle get buttonCompact =>
      _inter(size: 14, weight: FontWeight.w700, height: 1.2, color: AppColors.ctaInk);

  /// Link discreto ("Esqueci a senha")
  static TextStyle get link =>
      _inter(size: 13.5, weight: FontWeight.w600, height: 1.2, color: AppColors.primary);

  /// Contadores e números (filtros, badges, percentuais)
  static TextStyle get counter =>
      _mono(size: 11, weight: FontWeight.w600, height: 1.2);

  /// CPF mascarado, cronômetro e códigos — o token "code / mono" do canvas
  static TextStyle get code =>
      _mono(size: 12, weight: FontWeight.w600, height: 1.2, color: AppColors.text3);

  // ─── Checklist (quadro "1b" do canvas) ────────────────────────────────────

  /// Nome do participante no cabeçalho — 16/1.25 no canvas (o `cardTitle`
  /// tem altura de linha 1.3)
  static TextStyle get checklistParticipantName =>
      _inter(size: 16, weight: FontWeight.w600, height: 1.25);

  /// "salvo", ao lado do cronômetro
  static TextStyle get savedLabel =>
      _inter(size: 11.5, weight: FontWeight.w500, height: 1.2, color: AppColors.savedInk);

  /// Nota geral do participante, acima da barra ("86,7%")
  static TextStyle get checklistProgressValue =>
      _inter(size: 12, weight: FontWeight.w600, height: 1.2, color: AppColors.primaryDark);

  /// "A avaliação ainda não começou." (quadro "6a")
  static TextStyle get notStartedTitle =>
      _inter(size: 17, weight: FontWeight.w700, height: 1.3);

  /// Explicação sob o título da tela "não iniciada" (quadro "6a")
  static TextStyle get notStartedBody =>
      _inter(size: 13.5, weight: FontWeight.w400, height: 1.5, color: AppColors.text2);

  /// Código da categoria no chip do acordeão ("CV")
  static TextStyle get categoryCode =>
      _mono(size: 11, weight: FontWeight.w700, height: 1.2, letterSpacing: 0.44);

  /// Nome da categoria no acordeão ("Controle do Veículo")
  static TextStyle get categoryName =>
      _inter(size: 15, weight: FontWeight.w600, height: 1.25);

  /// "6 itens", na categoria fechada
  static TextStyle get categoryCount =>
      _inter(size: 12, weight: FontWeight.w400, height: 1.3, color: AppColors.textMuted);

  /// Selo de score da categoria aberta ("86,7%"). A tela de resultado (quadro
  /// "5a", Fase 5) desenha o dela com 11,5.
  static TextStyle get scoreBadge =>
      _inter(size: 11, weight: FontWeight.w700, height: 1.3);

  /// Número do item da infração na ficha oficial
  static TextStyle get infractionNumber =>
      _mono(size: 12, weight: FontWeight.w600, height: 1.55, color: AppColors.textMuted);

  /// Descrição da infração ("bodyLarge" da escala do canvas)
  static TextStyle get infractionDescription =>
      _inter(size: 16, weight: FontWeight.w400, height: 1.4);

  /// Código B/PM/M dentro do botão de nota
  static TextStyle get noteButton =>
      _inter(size: 15, weight: FontWeight.w700, height: 1.1);

  /// Observação da nota escolhida, na caixa abaixo dos botões
  static TextStyle get noteComment =>
      _inter(size: 13.5, weight: FontWeight.w400, height: 1.45, color: AppColors.noteCommentInk);

  // ─── Conferir e finalizar (quadro "2e" do canvas) ─────────────────────────

  /// "Pontuação final", acima do número
  static TextStyle get summaryScoreLabel =>
      _inter(size: 13, weight: FontWeight.w500, height: 1.2, color: AppColors.text3);

  /// O % geral em destaque ("86,7%")
  static TextStyle get summaryScore =>
      _inter(size: 40, weight: FontWeight.w800, height: 1, letterSpacing: -0.8);

  /// Pílula do resultado, ao lado do % ("Aprovado")
  static TextStyle get resultPill =>
      _inter(size: 12.5, weight: FontWeight.w600, height: 1.2);

  /// "Ana Paula Ribeiro · 3 infrações · mínimo para aprovação 70%."
  static TextStyle get summaryDetail =>
      _inter(size: 13, weight: FontWeight.w400, height: 1.45, color: AppColors.text3);

  /// "Por categoria"
  static TextStyle get summarySectionTitle =>
      _inter(size: 13, weight: FontWeight.w600, height: 1.2, color: AppColors.text3);

  /// Campo de senha mascarado
  static TextStyle get passwordDots =>
      _mono(size: 18, weight: FontWeight.w600, height: 1.3, letterSpacing: 2.5);
}
