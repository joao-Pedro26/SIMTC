'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { Loader2 } from 'lucide-react'
import { InputSearch } from '@/components/ui/input-search/input-search'
import { TrainingSessionStatusBadge } from '@/features/training-sessions/training-session-status-badge'
import { clientApi } from '@/lib/client-api'
import { PageTitle } from '@/components/header/page-title'
import type { TrainingStatus } from '@/features/training-sessions/types'
import styles from './page.module.css'
import tableStyles from './report-table.module.css'

interface ReportSession {
  id: string
  company: { id: string; name: string }
  course: { id: string; name: string }
  responsibleConsultant: { id: string; name: string } | null
  status: TrainingStatus
  date?: string | null
  createdAt: string
  _count: { participants: number }
}

function formatDate(dateStr?: string | null): string {
  if (!dateStr) return '—'
  const [year, month, day] = dateStr.split('T')[0].split('-')
  if (!year || !month || !day) return '—'
  return `${day}/${month}/${year}`
}

export default function RelatoriosPage() {
  const router = useRouter()
  const [sessions, setSessions] = useState<ReportSession[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [query, setQuery] = useState('')

  useEffect(() => {
    clientApi.get<ReportSession[]>('/reports/training-sessions')
      .then(setSessions)
      .catch((e) => setError(e instanceof Error ? e.message : 'Erro ao carregar relatórios'))
      .finally(() => setLoading(false))
  }, [])

  const filtered = sessions.filter((s) => {
    const q = query.toLowerCase()
    return (
      s.company.name.toLowerCase().includes(q) ||
      s.course.name.toLowerCase().includes(q)
    )
  })

  return (
    <div className={styles.page}>
      <PageTitle title="Relatórios" />

      <div className={styles.searchPanel}>
        <InputSearch
          value={query}
          onChange={setQuery}
          placeholder="Buscar por empresa ou curso..."
        />
      </div>

      <div className={styles.tablePanel}>
        {loading && (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '4rem' }}>
            <Loader2 size={32} style={{ opacity: 0.3 }} />
          </div>
        )}
        {error && <p style={{ color: 'var(--error)', padding: '1.5rem' }}>{error}</p>}

        {!loading && !error && (
          <div className={styles.tableWrapper}>
            {sessions.length === 0 ? (
              <p className={tableStyles.empty}>Nenhum treinamento encontrado.</p>
            ) : (
              <div className={tableStyles.wrapper}>
                <table className={tableStyles.table}>
                  <thead>
                    <tr className={tableStyles.headRow}>
                      <th className={tableStyles.th}>Empresa</th>
                      <th className={tableStyles.th}>Curso</th>
                      <th className={tableStyles.th}>Data</th>
                      <th className={tableStyles.th}>Consultor Responsável</th>
                      <th className={`${tableStyles.th} ${tableStyles.center}`}>Participantes</th>
                      <th className={`${tableStyles.th} ${tableStyles.center}`}>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filtered.length === 0 ? (
                      <tr>
                        <td colSpan={6} className={tableStyles.empty}>
                          Nenhum resultado para &quot;{query}&quot;.
                        </td>
                      </tr>
                    ) : (
                      filtered.map((s) => (
                        <tr
                          key={s.id}
                          className={tableStyles.row}
                          onClick={() => router.push(`/reports/${s.id}`)}
                        >
                          <td className={tableStyles.td}>{s.company.name}</td>
                          <td className={tableStyles.td}>{s.course.name}</td>
                          <td className={tableStyles.td}>{formatDate(s.date)}</td>
                          <td className={tableStyles.td}>{s.responsibleConsultant?.name ?? 'Consultor removido'}</td>
                          <td className={`${tableStyles.td} ${tableStyles.center}`}>
                            {s._count.participants}
                          </td>
                          <td className={`${tableStyles.td} ${tableStyles.center}`}>
                            <TrainingSessionStatusBadge status={s.status} />
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
