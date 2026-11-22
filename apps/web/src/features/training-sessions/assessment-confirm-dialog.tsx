'use client'

import { Loader2 } from 'lucide-react'
import { assessmentTimesError, type AssessmentTimes } from '@/lib/assessment-times'
import { AssessmentTimesFields } from './assessment-times-fields'
import styles from './assessment-confirm-dialog.module.css'

interface CategoryScore {
  code: string
  name: string
  score: number
}

interface AssessmentConfirmDialogProps {
  times: AssessmentTimes
  onTimesChange: (times: AssessmentTimes) => void
  categoryScores: CategoryScore[]
  overallScore: number
  faultCount: number
  observationCount: number
  approvalLabel: string
  saving: boolean
  onConfirm: () => void
  onCancel: () => void
}

function getResultClass(score: number): string {
  if (score >= 70) return styles.resultAprovado
  return styles.resultReprovado
}

export function AssessmentConfirmDialog({
  times,
  onTimesChange,
  categoryScores,
  overallScore,
  faultCount,
  observationCount,
  approvalLabel,
  saving,
  onConfirm,
  onCancel,
}: AssessmentConfirmDialogProps) {
  const timesError = assessmentTimesError(times)
  return (
    <div className={styles.overlay} role="dialog" aria-modal="true" aria-labelledby="assess-confirm-title">
      <div className={styles.dialog}>
        <h2 id="assess-confirm-title" className={styles.title}>
          Confirmar Avaliação
        </h2>

        {/* Data e horários: editáveis, porque a nota pode ser lançada depois
            da avaliação — o relatório deve mostrar quando ela aconteceu. */}
        <AssessmentTimesFields
          idPrefix="assess-confirm"
          value={times}
          onChange={onTimesChange}
          error={timesError}
          disabled={saving}
        />
        <p className={styles.timesHint}>
          Lançando depois? Ajuste para quando a avaliação aconteceu: é o que sai no relatório.
        </p>

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
                      backgroundColor: cs.score > 75 ? '#48bb78' : cs.score > 50 ? '#ecc94b' : '#fc8181',
                    }}
                  />
                </div>
                <span className={styles.catPercent}>{Math.round(cs.score)}%</span>
              </div>
            ))}
          </div>
        ) : (
          <p className={styles.noItems}>
            Nenhuma infração marcada — pontuação máxima em todas as categorias.
          </p>
        )}

        {/* Total de faltas e observações */}
        <p className={styles.noItems}>
          {faultCount} {faultCount === 1 ? 'falta' : 'faltas'}
          {observationCount > 0 &&
            ` · ${observationCount} ${observationCount === 1 ? 'observação' : 'observações'}`}
        </p>

        {/* Resultado geral */}
        <div className={styles.overallRow}>
          <span className={styles.overallLabel}>Resultado Final</span>
          <div className={styles.overallRight}>
            <span className={styles.overallScore}>{Math.round(overallScore)}%</span>
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
          <button className={styles.confirmBtn} onClick={onConfirm} disabled={saving || timesError !== null}>
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
