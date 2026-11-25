'use client'

import { useEffect, useRef, useState } from 'react'
import { useDrawerGuard } from '@/components/ui/drawer/drawer-guard'
import { Button } from '@/components/ui/button/button'
import { useSubmitLock } from '@/lib/use-submit-lock'
import { VehicleTypeField, type VehicleTypeActions, type VehicleTypeOption } from './vehicle-type-field'
import { isMissingTopics, type CourseFormData } from './course-edit-form'
import { ContentItemsEditor } from './content-items-editor'
import { CourseTopicsPicker, type CourseTopicOption } from './course-topics-picker'
import styles from './course-edit-form.module.css'

interface CourseAddFormProps {
  vehicleTypes: VehicleTypeOption[]
  vehicleTypeActions: VehicleTypeActions
  topics: CourseTopicOption[]
  topicsLoading?: boolean
  onSave: (data: CourseFormData) => void | Promise<void>
  onCancel: () => void
}

const empty: CourseFormData = {
  name: '',
  vehicleTypeId: '',
  practicalHours: '0',
  theoreticalHours: '0',
  description: '',
  contentItems: [],
  categoryIds: [],
}

export function CourseAddForm({
  vehicleTypes,
  vehicleTypeActions,
  topics,
  topicsLoading = false,
  onSave,
  onCancel,
}: CourseAddFormProps) {
  const [form, setForm] = useState<CourseFormData>(() => ({
    ...empty,
    vehicleTypeId: vehicleTypes[0]?.id ?? '',
    categoryIds: topics.map((t) => t.id),
  }))

  const { pending, run } = useSubmitLock()
  const save = () => run(() => onSave(form))

  // O estado inicial se completa depois de abrir (tipos e tópicos carregam): compara com o padrão atual.
  useDrawerGuard(form, save, {
    baseline: {
      ...empty,
      vehicleTypeId: vehicleTypes[0]?.id ?? '',
      categoryIds: topics.map((t) => t.id),
    },
  })

  // Se o tipo escolhido foi excluído (ou a lista chegou depois), cai no primeiro disponível
  useEffect(() => {
    setForm((prev) =>
      vehicleTypes.some((t) => t.id === prev.vehicleTypeId)
        ? prev
        : { ...prev, vehicleTypeId: vehicleTypes[0]?.id ?? '' },
    )
  }, [vehicleTypes])

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

        <VehicleTypeField
          value={form.vehicleTypeId}
          onChange={(id) => handleChange('vehicleTypeId', id)}
          vehicleTypes={vehicleTypes}
          actions={vehicleTypeActions}
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

      </div>

      <div className={styles.actions}>
        <div />
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
      </div>
    </div>
  )
}
