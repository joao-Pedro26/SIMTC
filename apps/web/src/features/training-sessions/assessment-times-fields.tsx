'use client'

import type { ChangeEvent } from 'react'
import type { AssessmentTimes } from '@/lib/assessment-times'
import { toDateInput } from '@/lib/assessment-times'
import styles from './assessment-times-fields.module.css'

interface AssessmentTimesFieldsProps {
  value: AssessmentTimes
  onChange: (value: AssessmentTimes) => void
  /** Mensagem de `assessmentTimesError`, ou null */
  error: string | null
  disabled?: boolean
  idPrefix: string
}

/**
 * Data, hora de início e de término de uma avaliação — os três campos que
 * saem no relatório. Usado ao lançar a avaliação e ao corrigir uma já salva.
 */
export function AssessmentTimesFields({ value, onChange, error, disabled, idPrefix }: AssessmentTimesFieldsProps) {
  const set = (field: keyof AssessmentTimes) => (e: ChangeEvent<HTMLInputElement>) =>
    onChange({ ...value, [field]: e.target.value })

  return (
    <div className={styles.wrapper}>
      <div className={styles.row}>
        <div className={styles.field}>
          <label className={styles.label} htmlFor={`${idPrefix}-date`}>Data</label>
          <input
            id={`${idPrefix}-date`}
            type="date"
            className={styles.input}
            value={value.date}
            max={toDateInput(new Date())}
            onChange={set('date')}
            disabled={disabled}
          />
        </div>
        <div className={styles.field}>
          <label className={styles.label} htmlFor={`${idPrefix}-start`}>H. Início</label>
          <input
            id={`${idPrefix}-start`}
            type="time"
            className={styles.input}
            value={value.start}
            onChange={set('start')}
            disabled={disabled}
          />
        </div>
        <div className={styles.field}>
          <label className={styles.label} htmlFor={`${idPrefix}-end`}>H. Fim</label>
          <input
            id={`${idPrefix}-end`}
            type="time"
            className={styles.input}
            value={value.end}
            onChange={set('end')}
            disabled={disabled}
          />
        </div>
      </div>
      {error && <p className={styles.error} role="alert">{error}</p>}
    </div>
  )
}
