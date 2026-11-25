'use client'

import { useState } from 'react'
import { useDrawerGuard } from '@/components/ui/drawer/drawer-guard'
import { Button } from '@/components/ui/button/button'
import { useSubmitLock } from '@/lib/use-submit-lock'
import type { Course } from './course-table'
import { VehicleTypeField, type VehicleTypeActions, type VehicleTypeOption } from './vehicle-type-field'
import { ContentItemsEditor, type ContentItem } from './content-items-editor'
import { CourseTopicsPicker, type CourseTopicOption } from './course-topics-picker'
import styles from './course-edit-form.module.css'

export interface CourseFormData {
  name: string
  vehicleTypeId: string
  practicalHours: string
  theoreticalHours: string
  description: string
  contentItems: ContentItem[]
  /** Tópicos de avaliação prática que valem para o curso */
  categoryIds: string[]
}

/** Curso com horas práticas precisa de ao menos 1 tópico (mesma regra do backend) */
export function isMissingTopics(form: Pick<CourseFormData, 'practicalHours' | 'categoryIds'>) {
  return Number(form.practicalHours) > 0 && form.categoryIds.length === 0
}

interface CourseEditFormProps {
  course: Course
  vehicleTypes: VehicleTypeOption[]
  /** Gerenciar (criar/excluir) tipos — ausente para CONSULTANT */
  vehicleTypeActions?: VehicleTypeActions
  topics: CourseTopicOption[]
  topicsLoading?: boolean
  onSave: (data: CourseFormData) => void | Promise<void>
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

export function CourseEditForm({
  course,
  vehicleTypes,
  vehicleTypeActions,
  topics,
  topicsLoading = false,
  onSave,
  onDelete,
  onCancel,
  readOnly = false,
}: CourseEditFormProps) {
  const [form, setForm] = useState<CourseFormData>({
    name: course.name,
    vehicleTypeId: course.vehicleTypeId ?? '',
    practicalHours: String(course.practicalHours),
    theoreticalHours: String(course.theoreticalHours),
    description: course.description,
    contentItems: normalizeContentItems((course as any).contentItems),
    categoryIds: course.categoryIds ?? [],
  })

  const { pending, run } = useSubmitLock()
  const save = () => run(() => onSave(form))

  useDrawerGuard(form, save, { enabled: !readOnly })

  function handleChange(field: keyof Omit<CourseFormData, 'contentItems' | 'categoryIds'>, value: string) {
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

        <VehicleTypeField
          value={form.vehicleTypeId}
          onChange={(id) => handleChange('vehicleTypeId', id)}
          vehicleTypes={vehicleTypes}
          actions={readOnly ? undefined : vehicleTypeActions}
        />

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
              <Button
                variant="primary"
                size="sm"
                onClick={save}
                disabled={pending || topicsLoading || isMissingTopics(form) || !form.vehicleTypeId}
              >
                {pending ? 'Salvando...' : 'Salvar'}
              </Button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
