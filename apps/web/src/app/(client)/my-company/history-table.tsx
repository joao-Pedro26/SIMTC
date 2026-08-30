'use client'

import Link from 'next/link'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { ColumnFilter } from '@/components/ui/column-filter/column-filter'
import { TrainingSessionStatusBadge } from '@/features/training-sessions/training-session-status-badge'
import type { TrainingStatus } from '@/features/training-sessions/types'
import styles from './page.module.css'

export interface TrainingHistoryItem {
  id: string
  date?: string | null
  city: string
  state: string
  status: TrainingStatus
  course: { name: string }
  _count: { participants: number }
}

// Mesmas opções/valores usados em features/training-sessions/training-session-table.tsx (admin).
const statusOptions = [
  { label: 'Planejado',    value: 'PLANEJADO'    },
  { label: 'Em Andamento', value: 'EM_ANDAMENTO' },
  { label: 'Concluído',    value: 'CONCLUIDO'    },
  { label: 'Cancelado',    value: 'CANCELADO'    },
]

function formatDate(dateStr?: string | null): string {
  if (!dateStr) return '—'
  return new Date(dateStr).toLocaleDateString('pt-BR')
}

function formatLocal(city: string, state: string): string {
  return city && state ? `${city}/${state}` : city || '—'
}

// Extraído de page.tsx (Server Component) para ter interatividade: cada linha
// inteira navega para o detalhe do treinamento, e todas as colunas têm filtro
// (mesmo componente ColumnFilter usado na tabela de treinamentos do admin).
export function HistoryTable({ history }: { history: TrainingHistoryItem[] }) {
  const router = useRouter()
  const [dateFilter, setDateFilter] = useState('')
  const [localFilter, setLocalFilter] = useState('')
  const [courseFilter, setCourseFilter] = useState('')
  const [participantsFilter, setParticipantsFilter] = useState('')
  const [statusFilter, setStatusFilter] = useState('')

  if (history.length === 0) {
    return <p className={styles.empty}>Nenhum treinamento registrado.</p>
  }

  const filtered = history.filter((item) => {
    const matchDate = formatDate(item.date).toLowerCase().includes(dateFilter.toLowerCase())
    const matchLocal = formatLocal(item.city, item.state).toLowerCase().includes(localFilter.toLowerCase())
    const matchCourse = item.course.name.toLowerCase().includes(courseFilter.toLowerCase())
    const matchParticipants = String(item._count.participants).includes(participantsFilter.trim())
    const matchStatus = statusFilter === '' || item.status === statusFilter
    return matchDate && matchLocal && matchCourse && matchParticipants && matchStatus
  })

  return (
    <div className={styles.tableWrapper}>
      <table className={styles.table}>
        <thead>
          <tr className={styles.headRow}>
            <ColumnFilter type="text" label="Data" value={dateFilter} onChange={setDateFilter} className={styles.th} />
            <ColumnFilter type="text" label="Local" value={localFilter} onChange={setLocalFilter} className={styles.th} />
            <ColumnFilter type="text" label="Curso" value={courseFilter} onChange={setCourseFilter} className={styles.th} />
            <ColumnFilter
              type="text"
              label="Participantes"
              value={participantsFilter}
              onChange={setParticipantsFilter}
              className={`${styles.th} ${styles.center}`}
            />
            <ColumnFilter
              type="select"
              label="Status"
              value={statusFilter}
              onChange={setStatusFilter}
              options={statusOptions}
              className={`${styles.th} ${styles.center}`}
            />
          </tr>
        </thead>
        <tbody>
          {filtered.length === 0 ? (
            <tr>
              <td colSpan={5} className={styles.noResults}>
                Nenhum resultado com os filtros aplicados.
              </td>
            </tr>
          ) : (
            filtered.map((item) => (
              <tr
                key={item.id}
                className={styles.clickableRow}
                onClick={() => router.push(`/my-company/trainings/${item.id}`)}
              >
                <td>{formatDate(item.date)}</td>
                <td>{formatLocal(item.city, item.state)}</td>
                <td>
                  <Link
                    href={`/my-company/trainings/${item.id}`}
                    className={styles.rowLink}
                    onClick={(e) => e.stopPropagation()}
                  >
                    {item.course.name}
                  </Link>
                </td>
                <td className={styles.center}>{item._count.participants}</td>
                <td className={styles.center}>
                  <TrainingSessionStatusBadge status={item.status} />
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  )
}
