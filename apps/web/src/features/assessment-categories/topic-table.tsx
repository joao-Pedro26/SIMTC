import { Pencil, Trash2, Eye } from 'lucide-react'
import styles from './topic-table.module.css'

export interface Topic {
  id: string
  sigla: string
  name: string
  disciplinaryText: string
}

interface TopicTableProps {
  topics: Topic[]
  onEdit: (topic: Topic) => void
  onDelete: (topic: Topic) => void
  /** Modo somente-leitura (ex.: CONSULTANT) — mostra apenas ícone de visualizar */
  readOnly?: boolean
}

export function TopicTable({ topics, onEdit, onDelete, readOnly = false }: TopicTableProps) {
  if (topics.length === 0) {
    return <p className={styles.empty}>Nenhum tópico encontrado.</p>
  }

  return (
    <div className={styles.wrapper}>
      <table className={styles.table}>
        <thead>
          <tr className={styles.headRow}>
            <th className={styles.th}>Sigla</th>
            <th className={styles.th}>Tópico</th>
            <th className={styles.th}>Texto Disciplinar</th>
            <th className={styles.th} />
          </tr>
        </thead>
        <tbody>
          {topics.map((t) => (
            <tr key={t.id} className={styles.row}>
              <td className={`${styles.td} ${styles.siglaCell}`}>{t.sigla}</td>
              <td className={`${styles.td} ${styles.nameCell}`}>{t.name}</td>
              <td className={styles.td}>
                <div className={styles.textClamp}>{t.disciplinaryText}</div>
              </td>
              <td className={`${styles.td} ${styles.actions}`}>
                {readOnly ? (
                  <button className={styles.actionBtn} onClick={() => onEdit(t)} aria-label="Visualizar">
                    <Eye size={15} />
                  </button>
                ) : (
                  <>
                    <button className={styles.actionBtn} onClick={() => onEdit(t)} aria-label="Editar">
                      <Pencil size={15} />
                    </button>
                    <button className={`${styles.actionBtn} ${styles.deleteBtn}`} onClick={() => onDelete(t)} aria-label="Deletar">
                      <Trash2 size={15} />
                    </button>
                  </>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
