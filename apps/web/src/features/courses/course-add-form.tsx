'use client'

import { useEffect, useRef, useState } from 'react'
import { Button } from '@/components/ui/button/button'
import { Select } from '@/components/ui/select/select'
import { isMissingTopics, type CourseFormData } from './course-edit-form'
import { ContentItemsEditor } from './content-items-editor'
import { CourseTopicsPicker, type CourseTopicOption } from './course-topics-picker'
import styles from './course-edit-form.module.css'

interface CourseAddFormProps {
  topics: CourseTopicOption[]
  topicsLoading?: boolean
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
  categoryIds: [],
}

export function CourseAddForm({ topics, topicsLoading = false, onSave, onCancel }: CourseAddFormProps) {
  const [form, setForm] = useState<CourseFormData>(() => ({
    ...empty,
    categoryIds: topics.map((t) => t.id),
  }))

  // Curso novo começa com todos os tópicos marcados — o admin desmarca o que
  // não se encaixa. Se a lista chegar depois de abrir o form, marca uma vez.
  const prefilled = useRef(topics.length > 0)
  useEffect(() => {
    if (prefilled.current || topics.length === 0) return
    prefilled.current = true
    setForm((prev) => ({ ...prev, categoryIds: topics.map((t) => t.id) }))
  }, [topics])

  function handleChange(field: keyof Omit<CourseFormData, 'contentItems' | 'categoryIds'>, value: string) {
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

        <CourseTopicsPicker
          topics={topics}
          loading={topicsLoading}
          selectedIds={form.categoryIds}
          onChange={(ids) => setForm((prev) => ({ ...prev, categoryIds: ids }))}
          required={Number(form.practicalHours) > 0}
        />

        <ContentItemsEditor
          items={form.contentItems}
          onChange={(items) => setForm((prev) => ({ ...prev, contentItems: items }))}
        />

      </div>

      <div className={styles.actions}>
        <div />
        <div className={styles.actionsRight}>
          <Button variant="secondary" size="sm" onClick={onCancel}>Cancelar</Button>
          <Button
            variant="primary"
            size="sm"
            onClick={() => onSave(form)}
            disabled={topicsLoading || isMissingTopics(form)}
          >
            Salvar
          </Button>
        </div>
      </div>
    </div>
  )
}
