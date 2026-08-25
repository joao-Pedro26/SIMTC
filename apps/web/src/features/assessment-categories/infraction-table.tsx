import { Pencil, Trash2, Eye } from 'lucide-react'
import styles from './infraction-table.module.css'

export interface InfractionNote {
  comment: string
  deduction: number
}

export interface Infraction {
  id: string
  topicId: string
  topicName: string
  topicSigla: string
  name: string
  noteB: InfractionNote
  notePM: InfractionNote
  noteM: InfractionNote
}

interface InfractionTableProps {
  infractions: Infraction[]
  onEdit: (infraction: Infraction) => void
  onDelete: (infraction: Infraction) => void
  /** Modo somente-leitura (ex.: CONSULTANT) — mostra apenas ícone de visualizar */
  readOnly?: boolean
}

export function InfractionTable({ infractions, onEdit, onDelete, readOnly = false }: InfractionTableProps) {
  if (infractions.length === 0) {
    return <p className={styles.empty}>Nenhuma infração encontrada.</p>
  }

  return (
    <div className={styles.wrapper}>
      <table className={styles.table}>
        <thead>
          <tr className={styles.headRow}>
            <th className={styles.th}>Tópico</th>
            <th className={styles.th}>Infração</th>
            <th className={styles.th}>Notas</th>
            <th className={styles.th} />
          </tr>
        </thead>
        <tbody>
          {infractions.map((inf) => (
            <tr key={inf.id} className={styles.row}>
              <td className={`${styles.td} ${styles.topicCell}`}>{inf.topicName}</td>
              <td className={styles.td}>
                <div className={styles.nameClamp}>{inf.name}</div>
              </td>
              <td className={`${styles.td} ${styles.notesCell}`}>
                <span className={`${styles.chip} ${styles.chipB}`}>B</span>
                <span className={`${styles.chip} ${styles.chipPM}`}>PM</span>
                <span className={`${styles.chip} ${styles.chipM}`}>M</span>
              </td>
              <td className={`${styles.td} ${styles.actions}`}>
                {readOnly ? (
                  <button className={styles.actionBtn} onClick={() => onEdit(inf)} aria-label="Visualizar">
                    <Eye size={15} />
                  </button>
                ) : (
                  <>
                    <button className={styles.actionBtn} onClick={() => onEdit(inf)} aria-label="Editar">
                      <Pencil size={15} />
                    </button>
                    <button className={`${styles.actionBtn} ${styles.deleteBtn}`} onClick={() => onDelete(inf)} aria-label="Deletar">
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
