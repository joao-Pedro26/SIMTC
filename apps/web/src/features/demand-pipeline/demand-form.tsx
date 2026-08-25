'use client'

import { useState } from 'react'
import { Select } from '@/components/ui/select/select'
import { Button } from '@/components/ui/button/button'
import styles from './demand-form.module.css'

export interface DemandFormData {
  companyId: string
  consultantId: string
  courseId: string
  participantCount: string
  notes: string
  status: 'QUALIFICACAO' | 'ANALISE' | 'AGENDAMENTO'
}

interface SelectOption {
  value: string
  label: string
}

interface DemandFormProps {
  initial?: Partial<DemandFormData>
  companyOptions: SelectOption[]
  consultantOptions: SelectOption[]
  courseOptions: SelectOption[]
  onSave: (data: DemandFormData) => void
  onDelete?: () => void
  onCancel: () => void
}

const statusOptions = [
  { value: 'QUALIFICACAO', label: 'Em Qualificação' },
  { value: 'ANALISE',      label: 'Análise e Classificação' },
  { value: 'AGENDAMENTO',  label: 'Agendamento' },
]

const empty: DemandFormData = {
  companyId:        '',
  consultantId:     '',
  courseId:         '',
  participantCount: '',
  notes:            '',
  status:           'QUALIFICACAO',
}

export function DemandForm({
  initial,
  companyOptions,
  consultantOptions,
  courseOptions,
  onSave,
  onDelete,
  onCancel,
}: DemandFormProps) {
  const [form, setForm] = useState<DemandFormData>({ ...empty, ...initial })

  function set<K extends keyof DemandFormData>(key: K, value: DemandFormData[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
  }

  const isValid = form.companyId !== '' && form.consultantId !== '' && form.courseId !== ''

  return (
    <div className={styles.wrapper}>
      <div className={styles.fields}>

        {/* Empresa */}
        <div className={styles.field}>
          <label className={styles.label}>Empresa <span style={{ color: 'var(--error)' }}>*</span></label>
          <Select
            value={form.companyId}
            onChange={(v) => set('companyId', v)}
            options={companyOptions}
            placeholder="Selecionar empresa"
          />
        </div>

        {/* Responsável */}
        <div className={styles.field}>
          <label className={styles.label}>Responsável <span style={{ color: 'var(--error)' }}>*</span></label>
          <Select
            value={form.consultantId}
            onChange={(v) => set('consultantId', v)}
            options={consultantOptions}
            placeholder="Selecionar consultor"
          />
        </div>

        {/* Tipo de curso */}
        <div className={styles.field}>
          <label className={styles.label}>Tipo de Curso <span style={{ color: 'var(--error)' }}>*</span></label>
          <Select
            value={form.courseId}
            onChange={(v) => set('courseId', v)}
            options={courseOptions}
            placeholder="Selecionar curso"
          />
        </div>

        {/* Nº Participantes + Status */}
        <div className={styles.row2}>
          <div className={styles.field}>
            <label className={styles.label}>Nº Participantes (estimativa)</label>
            <input
              className={styles.input}
              type="number"
              min="0"
              value={form.participantCount}
              onChange={(e) => set('participantCount', e.target.value)}
              placeholder="Ex: 20"
            />
          </div>
          <div className={styles.field}>
            <label className={styles.label}>Status</label>
            <Select
              value={form.status}
              onChange={(v) => set('status', v as DemandFormData['status'])}
              options={statusOptions}
            />
          </div>
        </div>

        {/* Observações */}
        <div className={styles.field}>
          <label className={styles.label}>Observações</label>
          <textarea
            className={styles.textarea}
            value={form.notes}
            onChange={(e) => set('notes', e.target.value)}
            placeholder="Ex: em negociação para 180 pessoas"
            rows={3}
          />
        </div>

      </div>

      <div className={styles.actions}>
        {onDelete && (
          <Button variant="danger" size="md" onClick={onDelete}>Excluir</Button>
        )}
        <div className={styles.actionsRight}>
          <Button variant="secondary" size="md" onClick={onCancel}>Cancelar</Button>
          <Button variant="primary" size="md" disabled={!isValid} onClick={() => onSave(form)}>Salvar</Button>
        </div>
      </div>
    </div>
  )
}
