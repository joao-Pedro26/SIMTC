'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button/button'
import { Select } from '@/components/ui/select/select'
import type { TrainingCompany, TrainingCourse, TrainingConsultant } from './types'
import styles from './training-session-add-form.module.css'

export interface TrainingSessionFormData {
  companyId: string
  courseId: string
  responsibleConsultantId: string
  additionalConsultantIds: string[]
  city: string
  state: string
  date: string
  participantCount: string
  notes: string
}

const BR_STATES = [
  'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA',
  'PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO',
]

interface TrainingSessionAddFormProps {
  companies: TrainingCompany[]
  courses: TrainingCourse[]
  consultants: TrainingConsultant[]
  onSave: (data: TrainingSessionFormData) => void
  onCancel: () => void
}

const empty: TrainingSessionFormData = {
  companyId: '',
  courseId: '',
  responsibleConsultantId: '',
  additionalConsultantIds: [],
  city: '',
  state: '',
  date: '',
  participantCount: '',
  notes: '',
}

export function TrainingSessionAddForm({
  companies,
  courses,
  consultants,
  onSave,
  onCancel,
}: TrainingSessionAddFormProps) {
  const [form, setForm] = useState<TrainingSessionFormData>(empty)

  function set<K extends keyof TrainingSessionFormData>(field: K, value: TrainingSessionFormData[K]) {
    setForm((prev) => ({ ...prev, [field]: value }))
  }

  function toggleAdditional(id: string) {
    setForm((prev) => {
      const already = prev.additionalConsultantIds.includes(id)
      return {
        ...prev,
        additionalConsultantIds: already
          ? prev.additionalConsultantIds.filter((x) => x !== id)
          : [...prev.additionalConsultantIds, id],
      }
    })
  }

  const availableAdditional = consultants.filter(
    (c) => c.id !== form.responsibleConsultantId,
  )

  const isValid =
    form.companyId !== '' &&
    form.courseId !== '' &&
    form.responsibleConsultantId !== '' &&
    form.city.trim() !== '' &&
    form.state !== '' &&
    form.date !== ''

  return (
    <div className={styles.wrapper}>
      <div className={styles.form}>

        <div className={styles.field}>
          <label className={styles.label}>Empresa <span className={styles.required}>*</span></label>
          <Select
            value={form.companyId}
            onChange={(v) => set('companyId', v)}
            options={companies.map((c) => ({ label: c.name, value: c.id }))}
            placeholder="Selecionar empresa"
          />
        </div>

        <div className={styles.field}>
          <label className={styles.label}>Curso <span className={styles.required}>*</span></label>
          <Select
            value={form.courseId}
            onChange={(v) => set('courseId', v)}
            options={courses.map((c) => ({ label: c.name, value: c.id }))}
            placeholder="Selecionar curso"
          />
        </div>

        <div className={styles.field}>
          <label className={styles.label}>Consultor Responsável <span className={styles.required}>*</span></label>
          <Select
            value={form.responsibleConsultantId}
            onChange={(v) => {
              set('responsibleConsultantId', v)
              set('additionalConsultantIds', form.additionalConsultantIds.filter((id) => id !== v))
            }}
            options={consultants.map((c) => ({ label: c.name, value: c.id }))}
            placeholder="Selecionar consultor"
          />
        </div>

        <div className={styles.row2}>
          <div className={styles.field}>
            <label className={styles.label}>Cidade <span className={styles.required}>*</span></label>
            <input
              className={styles.input}
              value={form.city}
              onChange={(e) => set('city', e.target.value)}
              placeholder="Ex: Guarulhos"
            />
          </div>
          <div className={styles.field}>
            <label className={styles.label}>UF <span className={styles.required}>*</span></label>
            <Select
              value={form.state}
              onChange={(v) => set('state', v)}
              options={BR_STATES.map((s) => ({ label: s, value: s }))}
              placeholder="UF"
            />
          </div>
        </div>

        <div className={styles.row2}>
          <div className={styles.field}>
            <label className={styles.label}>Data <span className={styles.required}>*</span></label>
            <input
              className={styles.input}
              type="date"
              value={form.date}
              onChange={(e) => set('date', e.target.value)}
            />
          </div>
          <div className={styles.field}>
            <label className={styles.label}>Nº estimado de participantes</label>
            <input
              className={styles.input}
              type="number"
              min="0"
              value={form.participantCount}
              onChange={(e) => set('participantCount', e.target.value)}
              placeholder="0"
            />
          </div>
        </div>

        <div className={styles.field}>
          <label className={styles.label}>Consultores Adicionais</label>
          <div className={styles.multiSelect}>
            {availableAdditional.length === 0 && (
              <p className={styles.noConsultants}>Nenhum consultor disponível</p>
            )}
            {availableAdditional.map((c) => {
              const checked = form.additionalConsultantIds.includes(c.id)
              return (
                <label key={c.id} className={`${styles.checkItem} ${checked ? styles.checkItemSelected : ''}`}>
                  <input
                    type="checkbox"
                    className={styles.checkbox}
                    checked={checked}
                    onChange={() => toggleAdditional(c.id)}
                  />
                  {c.name}
                </label>
              )
            })}
          </div>
        </div>

        <div className={styles.field}>
          <label className={styles.label}>Observações</label>
          <textarea
            className={styles.textarea}
            value={form.notes}
            onChange={(e) => set('notes', e.target.value)}
            placeholder="Ex: Treinamento começa às 8h"
            rows={3}
          />
        </div>

      </div>

      <div className={styles.actions}>
        <div />
        <div className={styles.actionsRight}>
          <Button variant="secondary" size="sm" onClick={onCancel}>Cancelar</Button>
          <Button variant="primary" size="sm" disabled={!isValid} onClick={() => onSave(form)}>
            Salvar
          </Button>
        </div>
      </div>
    </div>
  )
}
