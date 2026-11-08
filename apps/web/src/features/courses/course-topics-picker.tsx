'use client'

import styles from './course-topics-picker.module.css'

export interface CourseTopicOption {
  id: string
  code: string
  name: string
}

interface CourseTopicsPickerProps {
  topics: CourseTopicOption[]
  selectedIds: string[]
  onChange: (ids: string[]) => void
  /** Mostra o aviso de "pelo menos 1 tópico" (curso com horas práticas) */
  required?: boolean
  loading?: boolean
}

/**
 * Escolha dos tópicos de avaliação prática (CV, RR, CS, ...) que valem para o
 * curso. Só os tópicos marcados aparecem no checklist e entram na nota.
 */
export function CourseTopicsPicker({
  topics,
  selectedIds,
  onChange,
  required = false,
  loading = false,
}: CourseTopicsPickerProps) {
  const selected = new Set(selectedIds)
  const missing = required && selected.size === 0

  function toggle(id: string) {
    const next = new Set(selected)
    if (next.has(id)) next.delete(id)
    else next.add(id)
    // Mantém a ordem canônica dos tópicos
    onChange(topics.filter((t) => next.has(t.id)).map((t) => t.id))
  }

  return (
    <div className={styles.wrapper}>
      <span className={styles.label}>Tópicos da Avaliação Prática:</span>
      <p className={styles.hint}>
        Só os tópicos marcados aparecem no checklist e entram no cálculo da nota deste curso.
      </p>

      {loading ? (
        <p className={styles.hint}>Carregando tópicos...</p>
      ) : topics.length === 0 ? (
        <p className={styles.hint}>Nenhum tópico cadastrado em Categorias de Avaliação.</p>
      ) : (
        <div className={styles.list}>
          {topics.map((t) => {
            const checked = selected.has(t.id)
            return (
              <label key={t.id} className={`${styles.item} ${checked ? styles.itemChecked : ''}`}>
                <input
                  type="checkbox"
                  className={styles.checkbox}
                  checked={checked}
                  onChange={() => toggle(t.id)}
                />
                <span className={styles.code}>{t.code}</span>
                <span className={styles.name}>{t.name}</span>
              </label>
            )
          })}
        </div>
      )}

      {missing && !loading && (
        <p className={styles.error}>
          Cursos com horas práticas precisam de pelo menos 1 tópico.
        </p>
      )}
    </div>
  )
}
