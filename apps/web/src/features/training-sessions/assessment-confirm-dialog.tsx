'use client'

import { Loader2 } from 'lucide-react'
import styles from './assessment-confirm-dialog.module.css'

interface CategoryScore {
  code: string
  name: string
  score: number
}

interface AssessmentConfirmDialogProps {
  startTime: Date
  endTime: Date
  categoryScores: CategoryScore[]
  overallScore: number
  approvalLabel: string
  saving: boolean
  onConfirm: () => void
  onCancel: () => void
}

function formatTime(d: Date): string {
  return d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
}

function formatDate(d: Date): string {
  return d.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

function getResultClass(score: number): string {
  if (score >= 85) return styles.resultExcelencia
  if (score >= 70) return styles.resultAprovado
  return styles.resultReprovado
}

export function AssessmentConfirmDialog({
  startTime,
  endTime,
  categoryScores,
  overallScore,
  approvalLabel,
  saving,
  onConfirm,
  onCancel,
}: AssessmentConfirmDialogProps) {
  return (
    <div className={styles.overlay} role="dialog" aria-modal="true" aria-labelledby="assess-confirm-title">
      <div className={styles.dialog}>
        <h2 id="assess-confirm-title" className={styles.title}>
          Confirmar Avaliação
        </h2>

        {/* Linha de data e horários */}
        <div className={styles.timeRow}>
          <div className={styles.timeItem}>
            <span className={styles.timeLabel}>Data</span>
            <span className={styles.timeValue}>{formatDate(startTime)}</span>
          </div>
          <div className={styles.timeDivider} />
          <div className={styles.timeItem}>
            <span className={styles.timeLabel}>H. Início</span>
            <span className={styles.timeValue}>{formatTime(startTime)}</span>
          </div>
          <div className={styles.timeDivider} />
          <div className={styles.timeItem}>
            <span className={styles.timeLabel}>H. Fim</span>
            <span className={styles.timeValue}>{formatTime(endTime)}</span>
          </div>
        </div>

        {/* Scores por categoria */}
        {categoryScores.length > 0 ? (
          <div className={styles.catScores}>
            {categoryScores.map((cs) => (
              <div key={cs.code} className={styles.catRow}>
                <span className={styles.catCode}>{cs.code}</span>
                <span className={styles.catName}>{cs.name}</span>
                <div className={styles.catBar}>
                  <div
                    className={styles.catBarFill}
                    style={{
                      width: `${cs.score}%`,
                      backgroundColor: cs.score >= 85 ? '#48bb78' : cs.score >= 70 ? '#ecc94b' : '#fc8181',
                    }}
                  />
                </div>
                <span className={styles.catPercent}>{Math.round(cs.score)} pts</span>
              </div>
            ))}
          </div>
        ) : (
          <p className={styles.noItems}>
            Nenhuma infração marcada — pontuação máxima em todas as categorias.
          </p>
        )}

        {/* Resultado geral */}
        <div className={styles.overallRow}>
          <span className={styles.overallLabel}>Resultado Final</span>
          <div className={styles.overallRight}>
            <span className={styles.overallScore}>{Math.round(overallScore)} pts</span>
            <span className={`${styles.resultBadge} ${getResultClass(overallScore)}`}>
              {approvalLabel}
            </span>
          </div>
        </div>

        {/* Ações */}
        <div className={styles.actions}>
          <button className={styles.cancelBtn} onClick={onCancel} disabled={saving}>
            Voltar
          </button>
          <button className={styles.confirmBtn} onClick={onConfirm} disabled={saving} autoFocus>
            {saving ? (
              <span className={styles.savingRow}>
                <Loader2 size={14} className={styles.savingSpinner} />
                Salvando…
              </span>
            ) : (
              'Confirmar'
            )}
          </button>
        </div>
      </div>
    </div>
  )
}
