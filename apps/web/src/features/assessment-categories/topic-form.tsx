'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button/button'
import type { Topic } from './topic-table'
import styles from './topic-form.module.css'

export interface TopicFormData {
  sigla: string
  name: string
  disciplinaryText: string
}

interface TopicEditFormProps {
  topic: Topic
  onSave: (data: TopicFormData) => void
  onDelete: () => void
  onCancel: () => void
  /** Modo somente-leitura (ex.: CONSULTANT) — trava campos e some com salvar/excluir */
  readOnly?: boolean
}

interface TopicAddFormProps {
  onSave: (data: TopicFormData) => void
  onCancel: () => void
}

export function TopicEditForm({ topic, onSave, onDelete, onCancel, readOnly = false }: TopicEditFormProps) {
  const [form, setForm] = useState<TopicFormData>({
    sigla: topic.sigla,
    name: topic.name,
    disciplinaryText: topic.disciplinaryText,
  })

  function handleChange(field: keyof TopicFormData, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }))
  }

  return (
    <div className={styles.wrapper}>
      <fieldset disabled={readOnly} className={styles.form} style={{ border: 0, margin: 0, padding: 0 }}>
        <div className={styles.row2}>
          <div className={styles.field}>
            <label className={styles.label}>Tópico:</label>
            <input className={styles.input} value={form.name} onChange={(e) => handleChange('name', e.target.value)} />
          </div>
          <div className={styles.field}>
            <label className={styles.label}>Sigla:</label>
            <input className={styles.input} value={form.sigla} onChange={(e) => handleChange('sigla', e.target.value)} style={{ textTransform: 'uppercase' }} />
          </div>
        </div>

        <div className={styles.fieldGrow}>
          <label className={styles.label}>Texto Disciplinar:</label>
          <textarea className={styles.textarea} value={form.disciplinaryText} onChange={(e) => handleChange('disciplinaryText', e.target.value)} />
        </div>
      </fieldset>

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

const emptyTopic: TopicFormData = { sigla: '', name: '', disciplinaryText: '' }

export function TopicAddForm({ onSave, onCancel }: TopicAddFormProps) {
  const [form, setForm] = useState<TopicFormData>(emptyTopic)

  function handleChange(field: keyof TopicFormData, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }))
  }

  return (
    <div className={styles.wrapper}>
      <div className={styles.form}>
        <div className={styles.row2}>
          <div className={styles.field}>
            <label className={styles.label}>Tópico:</label>
            <input className={styles.input} value={form.name} onChange={(e) => handleChange('name', e.target.value)} />
          </div>
          <div className={styles.field}>
            <label className={styles.label}>Sigla:</label>
            <input className={styles.input} value={form.sigla} onChange={(e) => handleChange('sigla', e.target.value)} style={{ textTransform: 'uppercase' }} />
          </div>
        </div>

        <div className={styles.fieldGrow}>
          <label className={styles.label}>Texto Disciplinar:</label>
          <textarea className={styles.textarea} value={form.disciplinaryText} onChange={(e) => handleChange('disciplinaryText', e.target.value)} />
        </div>
      </div>

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
