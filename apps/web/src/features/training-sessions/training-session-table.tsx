'use client'

import { useState } from 'react'
import { Trash2 } from 'lucide-react'
import { ColumnFilter } from '@/components/ui/column-filter/column-filter'
import type { TrainingSession } from './types'
import { TrainingSessionStatusBadge } from './training-session-status-badge'
import styles from './training-session-table.module.css'

interface TrainingSessionTableProps {
  sessions: TrainingSession[]
  onSelect: (session: TrainingSession) => void
  onDelete?: (id: string) => void
}

const statusOptions = [
  { label: 'Planejado',    value: 'PLANEJADO'    },
  { label: 'Em Andamento', value: 'EM_ANDAMENTO' },
  { label: 'Concluído',    value: 'CONCLUIDO'    },
  { label: 'Cancelado',    value: 'CANCELADO'    },
]

function CompanyLogo({ name, logoUrl }: { name: string; logoUrl: string | null }) {
  if (logoUrl) {
    return <img src={logoUrl} alt={name} className={styles.logo} />
  }
  const initials = name
    .split(' ')
    .slice(0, 2)
    .map((w) => w[0])
    .join('')
    .toUpperCase()
  return <span className={styles.logoFallback}>{initials}</span>
}

function formatDate(dateStr: string): string {
  if (!dateStr) return '—'
  const [year, month, day] = dateStr.split('-')
  if (!year || !month || !day) return '—'
  return `${day}/${month}/${year}`
}

export function TrainingSessionTable({ sessions, onSelect, onDelete }: TrainingSessionTableProps) {
  const [companyFilter, setCompanyFilter] = useState('')
  const [statusFilter,  setStatusFilter]  = useState('')

  const filtered = sessions.filter((s) => {
    const matchCompany = s.company.name.toLowerCase().includes(companyFilter.toLowerCase()) ||
      s.city.toLowerCase().includes(companyFilter.toLowerCase())
    const matchStatus  = statusFilter === '' || s.status === statusFilter
    return matchCompany && matchStatus
  })

  if (sessions.length === 0) {
    return <p className={styles.empty}>Nenhum treinamento encontrado.</p>
  }

  return (
    <div className={styles.wrapper}>
      <table className={styles.table}>
        <thead>
          <tr className={styles.headRow}>
            <ColumnFilter
              type="text"
              label="Empresa"
              value={companyFilter}
              onChange={setCompanyFilter}
              className={styles.th}
            />
            <th className={styles.th}>Curso</th>
            <th className={styles.th}>Data</th>
            <th className={styles.th}>Cidade / UF</th>
            <th className={styles.th}>Consultor Responsável</th>
            <th className={`${styles.th} ${styles.center}`}>Participantes</th>
            <ColumnFilter
              type="select"
              label="Status"
              value={statusFilter}
              onChange={setStatusFilter}
              options={statusOptions}
              className={`${styles.th} ${styles.center}`}
            />
            {onDelete && <th className={styles.th} />}
          </tr>
        </thead>
        <tbody>
          {filtered.length === 0 ? (
            <tr>
              <td colSpan={7} className={styles.empty}>
                Nenhum resultado com os filtros aplicados.
              </td>
            </tr>
          ) : (
            filtered.map((s) => (
              <tr
                key={s.id}
                className={styles.row}
                onClick={() => onSelect(s)}
              >
                <td className={styles.td}>
                  <div className={styles.companyCell}>
                    <CompanyLogo name={s.company.name} logoUrl={s.company.logoUrl ?? null} />
                    <span className={styles.companyName}>{s.company.name}</span>
                  </div>
                </td>
                <td className={styles.td}>{s.course.name}</td>
                <td className={styles.td}>{formatDate(s.date)}</td>
                <td className={styles.td}>{s.city} / {s.state}</td>
                <td className={styles.td}>
                  {s.responsibleConsultant?.name ?? 'Consultor removido'}
                  {s.additionalConsultants.length > 0 && (
                    <span className={styles.extra}>
                      {' '}+ {s.additionalConsultants.length}
                    </span>
                  )}
                </td>
                <td className={`${styles.td} ${styles.center}`}>{s.participantCount}</td>
                <td className={`${styles.td} ${styles.center}`}>
                  <TrainingSessionStatusBadge status={s.status} />
                </td>
                {onDelete && (
                  <td className={`${styles.td} ${styles.center}`}>
                    <button
                      className={styles.deleteBtn}
                      title="Excluir treinamento"
                      onClick={(e) => { e.stopPropagation(); onDelete(s.id) }}
                    >
                      <Trash2 size={14} />
                    </button>
                  </td>
                )}
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  )
}
