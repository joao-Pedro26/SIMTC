'use client'

import { useEffect, useState } from 'react'
import { Loader2 } from 'lucide-react'
import { clientApi } from '@/lib/client-api'
import {
  assessmentTimesError,
  assessmentTimesFromSaved,
  assessmentTimesPayload,
  type AssessmentTimes,
} from '@/lib/assessment-times'
import { AssessmentTimesFields } from './assessment-times-fields'
// Mesmo visual do diálogo de confirmação da avaliação
import styles from './assessment-confirm-dialog.module.css'

interface AssessmentTimesModalProps {
  participantName: string
  assessment: { id: string; date: string; startTime: string; endTime: string | null }
  /** Já existe PDF do relatório: avisa que ele só muda quando for gerado de novo */
  hasReport: boolean
  onClose: () => void
  onSaved: () => void
}

/**
 * Corrige a data e os horários de uma avaliação já salva (ADMIN), sem refazer
 * a avaliação. Nota e faltas não mudam.
 */
export function AssessmentTimesModal({ participantName, assessment, hasReport, onClose, onSaved }: AssessmentTimesModalProps) {
  const [times, setTimes] = useState<AssessmentTimes>(() => assessmentTimesFromSaved(assessment))
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const timesError = assessmentTimesError(times)

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape' && !saving) onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [saving, onClose])

  async function handleSave() {
    if (timesError) return
    setSaving(true)
    setError('')
    try {
      await clientApi.patch(`/practical-assessments/${assessment.id}/times`, assessmentTimesPayload(times))
      onSaved()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erro ao salvar data e horários')
      setSaving(false)
    }
  }

  return (
    <div className={styles.overlay} role="dialog" aria-modal="true" aria-labelledby="assess-times-title">
      <div className={styles.dialog}>
        <h2 id="assess-times-title" className={styles.title}>
          Data e horário da avaliação — {participantName}
        </h2>

        <AssessmentTimesFields
          idPrefix="assess-times"
          value={times}
          onChange={setTimes}
          error={timesError}
          disabled={saving}
        />
        <p className={styles.timesHint}>
          {hasReport
            ? 'A nota não muda. O relatório já gerado só é atualizado quando você gerar os documentos de novo.'
            : 'A nota não muda. É o que sai no relatório de avaliação.'}
        </p>

        {error && <p className={styles.timesError} role="alert">{error}</p>}

        <div className={styles.actions}>
          <button className={styles.cancelBtn} onClick={onClose} disabled={saving}>
            Cancelar
          </button>
          <button className={styles.confirmBtn} onClick={handleSave} disabled={saving || timesError !== null}>
            {saving ? (
              <span className={styles.savingRow}>
                <Loader2 size={14} className={styles.savingSpinner} />
                Salvando…
              </span>
            ) : (
              'Salvar'
            )}
          </button>
        </div>
      </div>
    </div>
  )
}
