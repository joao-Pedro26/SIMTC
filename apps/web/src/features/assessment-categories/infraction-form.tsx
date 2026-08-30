'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button/button'
import { Select } from '@/components/ui/select/select'
import type { Topic } from './topic-table'
import type { Infraction, InfractionNote } from './infraction-table'
import styles from './infraction-form.module.css'

export interface InfractionFormData {
  topicId: string
  name: string
  noteB: InfractionNote
  notePM: InfractionNote
  noteM: InfractionNote
}

const emptyForm = (): InfractionFormData => ({
  topicId: '',
  name: '',
  noteB:  { comment: '', deduction: 1 },
  notePM: { comment: '', deduction: 3 },
  noteM:  { comment: '', deduction: 5 },
})

interface InfractionEditFormProps {
  infraction: Infraction
  topics: Topic[]
  onSave: (data: InfractionFormData) => void
  onDelete: () => void
  onCancel: () => void
  readOnly?: boolean
}

interface InfractionAddFormProps {
  topics: Topic[]
  onSave: (data: InfractionFormData) => void
  onCancel: () => void
}

function NoteSection({
  label,
  colorClass,
  deduction,
  comment,
  onChange,
}: {
  label: string
  colorClass: string
  deduction: number
  comment: string
  onChange: (comment: string) => void
}) {
  return (
    <div className={styles.noteSection}>
      <div className={styles.noteHeader}>
        <span className={`${styles.noteChip} ${colorClass}`}>{label}</span>
      </div>
      <textarea
        className={styles.textarea}
        value={comment}
        onChange={(e) => onChange(e.target.value)}
        placeholder={`Comentário para nota ${label}...`}
      />
    </div>
  )
}

function InfractionFormBody({
  form,
  topics,
  onChange,
  readOnly = false,
}: {
  form: InfractionFormData
  topics: Topic[]
  onChange: (updates: Partial<InfractionFormData>) => void
  readOnly?: boolean
}) {
  const topicOptions = topics.map((t) => ({ label: t.name, value: t.id }))

  return (
    <fieldset disabled={readOnly} className={styles.form} style={{ border: 0, margin: 0, padding: 0 }}>
      <div className={styles.row2}>
        <div className={styles.field}>
          <label className={styles.label}>Tópico:</label>
          <Select
            value={form.topicId}
            onChange={(v) => onChange({ topicId: v })}
            options={topicOptions}
            placeholder="Selecionar tópico"
          />
        </div>
      </div>

      <div className={styles.field}>
        <label className={styles.label}>Título da infração:</label>
        <input
          className={styles.input}
          value={form.name}
          onChange={(e) => onChange({ name: e.target.value })}
          placeholder="Ex: Não ajustou banco e retrovisores antes de partir."
        />
      </div>

      <div className={styles.divider} />

      <p className={styles.sectionTitle}>Comentários por nota</p>

      <NoteSection
        label="B"
        colorClass={styles.chipB}
        deduction={form.noteB.deduction}
        comment={form.noteB.comment}
        onChange={(comment) => onChange({ noteB: { ...form.noteB, comment } })}
      />
      <NoteSection
        label="PM"
        colorClass={styles.chipPM}
        deduction={form.notePM.deduction}
        comment={form.notePM.comment}
        onChange={(comment) => onChange({ notePM: { ...form.notePM, comment } })}
      />
      <NoteSection
        label="M"
        colorClass={styles.chipM}
        deduction={form.noteM.deduction}
        comment={form.noteM.comment}
        onChange={(comment) => onChange({ noteM: { ...form.noteM, comment } })}
      />
    </fieldset>
  )
}

export function InfractionEditForm({ infraction, topics, onSave, onDelete, onCancel, readOnly = false }: InfractionEditFormProps) {
  const [form, setForm] = useState<InfractionFormData>({
    topicId: infraction.topicId,   // string CUID
    name: infraction.name,
    noteB:  infraction.noteB,
    notePM: infraction.notePM,
    noteM:  infraction.noteM,
  })

  function handleChange(updates: Partial<InfractionFormData>) {
    setForm((prev) => ({ ...prev, ...updates }))
  }

  return (
    <div className={styles.wrapper}>
      <InfractionFormBody form={form} topics={topics} onChange={handleChange} readOnly={readOnly} />
      <div className={styles.actions}>
        {readOnly ? (
          <div className={styles.actionsRight}>
            <Button variant="secondary" size="sm" onClick={onCancel}>Fechar</Button>
          </div>
        ) : (
          <>
            <Button variant="danger" size="sm" onClick={onDelete}>Deletar</Button>
            <div className={styles.actionsRight}>
              <Button variant="secondary" size="sm" onClick={onCancel}>Cancelar</Button>
              <Button variant="primary" size="sm" onClick={() => onSave(form)}>Salvar</Button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}

export function InfractionAddForm({ topics, onSave, onCancel }: InfractionAddFormProps) {
  const [form, setForm] = useState<InfractionFormData>(emptyForm())

  function handleChange(updates: Partial<InfractionFormData>) {
    setForm((prev) => ({ ...prev, ...updates }))
  }

  return (
    <div className={styles.wrapper}>
      <InfractionFormBody form={form} topics={topics} onChange={handleChange} />
      <div className={styles.actions}>
        <div />
        <div className={styles.actionsRight}>
          <Button variant="secondary" size="sm" onClick={onCancel}>Cancelar</Button>
          <Button variant="primary" size="sm" onClick={() => onSave(form)}>Salvar</Button>
        </div>
      </div>
    </div>
  )
}
