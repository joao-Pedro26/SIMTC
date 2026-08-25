'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { ChevronLeft, Loader2 } from 'lucide-react'
import { clientApi } from '@/lib/client-api'
import { PageTitle } from '@/components/header/page-title'
import { TrainingSessionStatusBadge } from '@/features/training-sessions/training-session-status-badge'
import { calculateCategoryScore, calculateOverallScore, getApprovalLabel } from '@simtc/shared-types'
import type { TrainingStatus } from '@/features/training-sessions/types'
import styles from './page.module.css'

// ─── Tipos que batem com o include do backend ─────────────────

interface AssessmentItem {
  infractionNote: {
    deduction: number
    infraction: {
      category: { id: string; name: string }
    }
  }
}

interface Assessment {
  score?: number | null
  items: AssessmentItem[]
}

interface Certificate {
  id: string
  sentAt?: string | null
}

interface SessionParticipant {
  id: string
  participationType: 'SOMENTE_TEORICA' | 'TEORICA_E_PRATICA'
  status: 'PENDENTE' | 'EM_AVALIACAO' | 'APROVADO' | 'NECESSITA_REAVALIACAO'
  participant: { id: string; name: string; cpf: string }
  assessment?: Assessment | null
  certificate?: Certificate | null
}

interface SessionDetail {
  id: string
  company: { id: string; name: string }
  course: { id: string; name: string }
  responsibleConsultant: { id: string; name: string } | null
  city: string
  state: string
  date?: string | null
  status: TrainingStatus
  participants: SessionParticipant[]
}

// ─── Helpers ──────────────────────────────────────────────────

function formatDate(dateStr?: string | null): string {
  if (!dateStr) return '—'
  const [year, month, day] = dateStr.split('T')[0].split('-')
  if (!year || !month || !day) return '—'
  return `${day}/${month}/${year}`
}

function computeScore(assessment: Assessment | null | undefined): number | null {
  if (!assessment || assessment.items.length === 0) return null
  // Group deductions by category
  const byCategory: Record<string, number[]> = {}
  for (const item of assessment.items) {
    const catId = item.infractionNote.infraction.category.id
    if (!byCategory[catId]) byCategory[catId] = []
    byCategory[catId].push(item.infractionNote.deduction)
  }
  const categoryScores = Object.values(byCategory).map(calculateCategoryScore)
  return Math.round(calculateOverallScore(categoryScores))
}

const participantStatusLabels: Record<string, string> = {
  PENDENTE: 'Pendente',
  EM_AVALIACAO: 'Em Avaliação',
  APROVADO: 'Aprovado',
  NECESSITA_REAVALIACAO: 'Nec. Reavaliação',
}

function ScoreBadge({ score, participationType }: { score: number | null; participationType: string }) {
  if (participationType === 'SOMENTE_TEORICA') {
    return <span className={`${styles.badge} ${styles.badgePending}`}>Só Teoria</span>
  }
  if (score === null) {
    return <span className={`${styles.badge} ${styles.badgePending}`}>—</span>
  }
  const label = getApprovalLabel(score)
  const cls = score >= 85 ? styles.badgeExcellence : score >= 70 ? styles.badgeApproved : styles.badgeFailed
  return <span className={`${styles.badge} ${cls}`}>{label} ({score}%)</span>
}

function CertBadge({ cert }: { cert?: Certificate | null }) {
  if (!cert) return <span className={`${styles.badge} ${styles.badgeNoCert}`}>—</span>
  return <span className={`${styles.badge} ${styles.badgeCert}`}>Gerado</span>
}

// ─── Página ───────────────────────────────────────────────────

export default function ReportDetailPage({ params }: { params: { id: string } }) {
  const { id } = params
  const router = useRouter()
  const [session, setSession] = useState<SessionDetail | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    clientApi.get<SessionDetail>(`/reports/training-sessions/${id}`)
      .then(setSession)
      .catch((e) => setError(e instanceof Error ? e.message : 'Erro ao carregar relatório'))
      .finally(() => setLoading(false))
  }, [id])

  if (loading) {
    return (
      <div className={styles.page}>
        <PageTitle title="Relatório" />
        <div style={{ display: 'flex', justifyContent: 'center', padding: '4rem' }}>
          <Loader2 size={32} style={{ opacity: 0.3 }} />
        </div>
      </div>
    )
  }

  if (error || !session) {
    return (
      <div className={styles.page}>
        <PageTitle title="Relatório" />
        <p style={{ color: 'var(--error)', padding: '1.5rem' }}>{error || 'Sessão não encontrada.'}</p>
      </div>
    )
  }

  const title = `${session.company.name} — ${session.course.name}`

  return (
    <div className={styles.page}>
      <PageTitle title="Relatórios" />

      <button className={styles.backBtn} onClick={() => router.push('/reports')}>
        <ChevronLeft size={16} />
        Voltar para Relatórios
      </button>

      {/* Cabeçalho da sessão */}
      <div className={styles.header}>
        <div className={styles.headerField}>
          <span className={styles.headerLabel}>Empresa</span>
          <span className={styles.headerValue}>{session.company.name}</span>
        </div>
        <div className={styles.headerField}>
          <span className={styles.headerLabel}>Curso</span>
          <span className={styles.headerValue}>{session.course.name}</span>
        </div>
        <div className={styles.headerField}>
          <span className={styles.headerLabel}>Data</span>
          <span className={styles.headerValue}>{formatDate(session.date)}</span>
        </div>
        <div className={styles.headerField}>
          <span className={styles.headerLabel}>Local</span>
          <span className={styles.headerValue}>{session.city} / {session.state}</span>
        </div>
        <div className={styles.headerField}>
          <span className={styles.headerLabel}>Consultor</span>
          <span className={styles.headerValue}>{session.responsibleConsultant?.name ?? 'Consultor removido'}</span>
        </div>
        <div className={styles.headerField}>
          <span className={styles.headerLabel}>Status</span>
          <TrainingSessionStatusBadge status={session.status} />
        </div>
      </div>

      {/* Tabela de participantes */}
      <div className={styles.tablePanel}>
        {session.participants.length === 0 ? (
          <p className={styles.empty}>Nenhum participante inscrito.</p>
        ) : (
          <div className={styles.tableWrapper}>
            <table className={styles.table}>
              <thead>
                <tr className={styles.headRow}>
                  <th className={styles.th}>Participante</th>
                  <th className={styles.th}>CPF</th>
                  <th className={`${styles.th} ${styles.center}`}>Tipo</th>
                  <th className={`${styles.th} ${styles.center}`}>Status</th>
                  <th className={`${styles.th} ${styles.center}`}>Nota Final</th>
                  <th className={`${styles.th} ${styles.center}`}>Certificado</th>
                </tr>
              </thead>
              <tbody>
                {session.participants.map((tp) => {
                  const score = computeScore(tp.assessment)
                  return (
                    <tr key={tp.id} className={styles.row}>
                      <td className={styles.td}>{tp.participant.name}</td>
                      <td className={styles.td}>{tp.participant.cpf}</td>
                      <td className={`${styles.td} ${styles.center}`}>
                        {tp.participationType === 'SOMENTE_TEORICA' ? 'Teoria' : 'Teoria + Prática'}
                      </td>
                      <td className={`${styles.td} ${styles.center}`}>
                        {participantStatusLabels[tp.status] ?? tp.status}
                      </td>
                      <td className={`${styles.td} ${styles.center}`}>
                        <ScoreBadge score={score} participationType={tp.participationType} />
                      </td>
                      <td className={`${styles.td} ${styles.center}`}>
                        <CertBadge cert={tp.certificate} />
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
