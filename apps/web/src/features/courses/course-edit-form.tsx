'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button/button'
import { Select } from '@/components/ui/select/select'
import type { Course } from './course-table'
import { ContentItemsEditor, type ContentItem } from './content-items-editor'
import styles from './course-edit-form.module.css'

export interface CourseFormData {
  name: string
  vehicleType: 'LEVE' | 'PESADO' | 'MOTO'
  practicalHours: string
  theoreticalHours: string
  description: string
  contentItems: ContentItem[]
}

const vehicleTypeOptions = [
  { value: 'LEVE',   label: 'Veículo Leve' },
  { value: 'PESADO', label: 'Veículo Pesado' },
  { value: 'MOTO',   label: 'Motocicleta' },
]

interface CourseEditFormProps {
  course: Course
  onSave: (data: CourseFormData) => void
  onDelete: () => void
  onCancel: () => void
  /** Modo somente-leitura (ex.: CONSULTANT) — trava todos os campos e some com salvar/excluir */
  readOnly?: boolean
}

function normalizeContentItems(raw: unknown): ContentItem[] {
  if (!Array.isArray(raw)) return []
  return raw.map((item: any) => ({
    left:      typeof item.left      === 'string'  ? item.left      : '',
    right:     typeof item.right     === 'string'  ? item.right     : '',
    leftBold:  typeof item.leftBold  === 'boolean' ? item.leftBold  : false,
    rightBold: typeof item.rightBold === 'boolean' ? item.rightBold : false,
  }))
}

export function CourseEditForm({ course, onSave, onDelete, onCancel, readOnly = false }: CourseEditFormProps) {
  const [form, setForm] = useState<CourseFormData>({
    name: course.name,
    vehicleType: (course as any).vehicleType ?? 'LEVE',
    practicalHours: String(course.practicalHours),
    theoreticalHours: String(course.theoreticalHours),
    description: course.description,
    contentItems: normalizeContentItems((course as any).contentItems),
  })

  function handleChange(field: keyof Omit<CourseFormData, 'contentItems'>, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }))
  }

  return (
    <div className={styles.wrapper}>
      <fieldset disabled={readOnly} className={styles.form} style={{ border: 0, margin: 0, padding: 0 }}>

        <div className={styles.field}>
          <label className={styles.label}>Nome do Curso:</label>
          <input
            className={styles.input}
            value={form.name}
            onChange={(e) => handleChange('name', e.target.value)}
          />
        </div>

        <div className={styles.field}>
          <label className={styles.label}>Tipo de Veículo:</label>
          <Select
            value={form.vehicleType}
            onChange={(v) => handleChange('vehicleType', v)}
            options={vehicleTypeOptions}
          />
        </div>

        <div className={styles.row2}>
          <div className={styles.field}>
            <label className={styles.label}>Horas Práticas:</label>
            <input
              className={styles.input}
              type="number"
              min="0"
              value={form.practicalHours}
              onChange={(e) => handleChange('practicalHours', e.target.value)}
            />
          </div>
          <div className={styles.field}>
            <label className={styles.label}>Horas Teóricas:</label>
            <input
              className={styles.input}
              type="number"
              min="0"
              value={form.theoreticalHours}
              onChange={(e) => handleChange('theoreticalHours', e.target.value)}
            />
          </div>
        </div>

        <div className={styles.field}>
          <label className={styles.label}>Descrição:</label>
          <textarea
            className={styles.textarea}
            value={form.description}
            onChange={(e) => handleChange('description', e.target.value)}
          />
        </div>

        <ContentItemsEditor
          items={form.contentItems}
          onChange={(items) => setForm((prev) => ({ ...prev, contentItems: items }))}
        />

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
