'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button/button'
import { Select } from '@/components/ui/select/select'
import type { CourseFormData } from './course-edit-form'
import { ContentItemsEditor } from './content-items-editor'
import styles from './course-edit-form.module.css'

interface CourseAddFormProps {
  onSave: (data: CourseFormData) => void
  onCancel: () => void
}

const vehicleTypeOptions = [
  { value: 'LEVE',   label: 'Veículo Leve' },
  { value: 'PESADO', label: 'Veículo Pesado' },
  { value: 'MOTO',   label: 'Motocicleta' },
]

const empty: CourseFormData = {
  name: '',
  vehicleType: 'LEVE',
  practicalHours: '0',
  theoreticalHours: '0',
  description: '',
  contentItems: [],
}

export function CourseAddForm({ onSave, onCancel }: CourseAddFormProps) {
  const [form, setForm] = useState<CourseFormData>(empty)

  function handleChange(field: keyof Omit<CourseFormData, 'contentItems'>, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }))
  }

  return (
    <div className={styles.wrapper}>
      <div className={styles.form}>

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
