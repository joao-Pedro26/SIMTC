'use client'

import { useState } from 'react'
import { Pencil, Trash2 } from 'lucide-react'
import { Button } from '@/components/ui/button/button'
import { Select } from '@/components/ui/select/select'
import type { Topic } from './topic-table'
import type { Infraction } from './infraction-table'
import styles from './infraction-manager.module.css'

interface InfractionManagerProps {
  topics: Topic[]
  infractions: Infraction[]
  onSave: (topicId: number, name: string) => void
  onDelete: (infraction: Infraction) => void
  onCancel: () => void
}

export function InfractionManager({ topics, infractions, onSave, onDelete, onCancel }: InfractionManagerProps) {
  const [selectedTopicId, setSelectedTopicId] = useState<string>('')
  const [infractionName, setInfractionName] = useState('')

  function handleSave() {
    if (!selectedTopicId || !infractionName.trim()) return
    onSave(Number(selectedTopicId), infractionName.trim())
    setInfractionName('')
  }

  const topicOptions = topics.map((t) => ({ label: t.name, value: String(t.id) }))

  return (
    <div className={styles.wrapper}>

      <div className={styles.formSection}>
        <div className={styles.field}>
          <label className={styles.label}>Tópico:</label>
          <Select
            value={selectedTopicId}
            onChange={setSelectedTopicId}
            options={topicOptions}
            placeholder="Selecionar tópico"
          />
        </div>

        <div className={styles.field}>
          <label className={styles.label}>Infração:</label>
          <input
            className={styles.input}
            value={infractionName}
            onChange={(e) => setInfractionName(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') handleSave() }}
          />
        </div>

        <div className={styles.saveRow}>
          <Button variant="primary" size="sm" onClick={handleSave}>Salvar</Button>
        </div>
      </div>

      <div className={styles.listSection}>
        {infractions.length === 0 && (
          <p className={styles.empty}>Nenhuma infração cadastrada.</p>
        )}
        {infractions.map((inf) => (
          <div key={inf.id} className={styles.item}>
            <span className={styles.itemSigla}>{inf.topicSigla}</span>
            <span className={styles.itemName}>{inf.name}</span>
            <div className={styles.itemActions}>
              <button className={styles.actionBtn} aria-label="Editar">
                <Pencil size={14} />
              </button>
              <button
                className={`${styles.actionBtn} ${styles.deleteBtn}`}
                onClick={() => onDelete(inf)}
                aria-label="Deletar"
              >
                <Trash2 size={14} />
              </button>
            </div>
          </div>
        ))}
      </div>

      <div className={styles.footer}>
        <Button variant="secondary" size="sm" onClick={onCancel}>Cancelar</Button>
      </div>
    </div>
  )
}
