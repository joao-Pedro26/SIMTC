import { CalendarCheck, Users, FileCheck, TrendingUp, ArrowUpRight, ChevronRight } from 'lucide-react'
import Link from 'next/link'
import { cn } from '@/lib/utils'
import { api } from '@/lib/api'
import { PageTitle } from '@/components/header/page-title'
import styles from './dashboard.module.css'

// ─── Tipos ───────────────────────────────────────────────────

type StatColor = 'teal' | 'orange' | 'mauve'

interface Stat {
  label: string
  value: string
  delta: string
  up: boolean
  icon: React.ElementType
  color: StatColor
}

interface BackendSession {
  id: string
  company: { id: string; name: string }
  course: { id: string; name: string }
  responsibleConsultant: { id: string; name: string } | null
  city: string
  state: string
  date?: string | null
  participantCount?: number | null
  status: string
  _count?: { participants: number }
  createdAt: string
}

// ─── Helpers ─────────────────────────────────────────────────

const colorBg: Record<StatColor, string> = {
  teal:   styles.bgTeal,
  orange: styles.bgOrange,
  mauve:  styles.bgMauve,
}

const colorIcon: Record<StatColor, string> = {
  teal:   styles.iconTeal,
  orange: styles.iconOrange,
  mauve:  styles.iconMauve,
}

const statusBadgeClass: Record<string, string> = {
  PLANEJADO:    styles.badgePlanejado,
  EM_ANDAMENTO: styles.badgeEmAndamento,
  CONCLUIDO:    styles.badgeConcluido,
  CANCELADO:    styles.badgeCancelado,
}

const statusLabel: Record<string, string> = {
  PLANEJADO:    'Planejado',
  EM_ANDAMENTO: 'Em andamento',
  CONCLUIDO:    'Concluído',
  CANCELADO:    'Cancelado',
}

function StatusBadge({ status }: { status: string }) {
  return (
    <span className={cn(styles.badge, statusBadgeClass[status] ?? styles.badgePlanejado)}>
      {statusLabel[status] ?? status}
    </span>
  )
}

function formatDate(iso?: string | null) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('pt-BR')
}

// ─── Página ───────────────────────────────────────────────────

export default async function DashboardPage() {
  const today = new Date().toLocaleDateString('pt-BR', {
    weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
  })

  // Busca dados reais do backend
  let sessions: BackendSession[] = []
  try {
    const result = await api.get<{ data: BackendSession[] }>('/training-sessions?limit=100')
    sessions = result.data ?? []
  } catch {
    // Se falhar (ex: sem token), mostra zero
  }

  // Calcula stats do mês atual
  const now = new Date()
  const thisMonth = sessions.filter((s) => {
    const d = new Date(s.createdAt)
    return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear()
  })

  const totalParticipants = sessions.reduce((acc, s) => acc + (s.participantCount ?? 0), 0)
  const completedSessions = sessions.filter((s) => s.status === 'CONCLUIDO')
  const approvalRate = completedSessions.length > 0
    ? `${((completedSessions.length / sessions.length) * 100).toFixed(1)}%`
    : '—'

  const stats: Stat[] = [
    {
      label: 'Treinamentos no mês',
      value: String(thisMonth.length),
      delta: `${sessions.length} total`,
      up: thisMonth.length > 0,
      icon: CalendarCheck,
      color: 'teal',
    },
    {
      label: 'Participantes (estimado)',
      value: String(totalParticipants),
      delta: `${completedSessions.length} concluídos`,
      up: completedSessions.length > 0,
      icon: Users,
      color: 'mauve',
    },
    {
      label: 'Treinamentos Concluídos',
      value: String(completedSessions.length),
      delta: `${sessions.filter((s) => s.status === 'PLANEJADO').length} planejados`,
      up: completedSessions.length > 0,
      icon: FileCheck,
      color: 'orange',
    },
    {
      label: 'Taxa de conclusão',
      value: approvalRate,
      delta: `de ${sessions.length} treinamentos`,
      up: completedSessions.length > 0,
      icon: TrendingUp,
      color: 'teal',
    },
  ]

  // Últimos 5 treinamentos
  const recentSessions = [...sessions]
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
    .slice(0, 5)

  return (
    <div className={styles.page}>
      <PageTitle title="Dashboard" />

      {/* Saudação */}
      <div className={styles.greeting}>
        <h2>Bem-vindo ao SIMTC</h2>
        <p>{today}</p>
      </div>

      {/* Cards de estatísticas */}
      <div className={styles.statsGrid}>
        {stats.map((stat) => {
          const Icon = stat.icon
          return (
            <div key={stat.label} className={styles.statCard}>
              <div className={styles.statTop}>
                <div className={cn(styles.statIconWrap, colorBg[stat.color])}>
                  <Icon size={18} className={colorIcon[stat.color]} />
                </div>
                <span className={cn(styles.statDelta, stat.up && styles.statDeltaUp)}>
                  {stat.up && <ArrowUpRight size={13} />}
                  {stat.delta}
                </span>
              </div>
              <div>
                <p className={styles.statValue}>{stat.value}</p>
                <p className={styles.statLabel}>{stat.label}</p>
              </div>
            </div>
          )
        })}
      </div>

      {/* Tabela de treinamentos recentes */}
      <div className={styles.tableCard}>

        <div className={styles.tableHeader}>
          <h3>Treinamentos recentes</h3>
          <Link href="/training-sessions" className={styles.viewAll}>
            Ver todos <ChevronRight size={13} />
          </Link>
        </div>

        <div className={styles.tableWrap}>
          {recentSessions.length === 0 ? (
            <p style={{ padding: '2rem', textAlign: 'center', opacity: 0.5 }}>
              Nenhum treinamento cadastrado ainda.
            </p>
          ) : (
            <table className={styles.table}>
              <thead>
                <tr>
                  {['Empresa', 'Curso', 'Data', 'Cidade', 'Consultor', 'Part.', 'Status'].map((h) => (
                    <th key={h}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {recentSessions.map((s) => (
                  <tr key={s.id}>
                    <td className={styles.tdBold}>{s.company.name}</td>
                    <td>{s.course.name}</td>
                    <td>{formatDate(s.date)}</td>
                    <td>{s.city}, {s.state}</td>
                    <td>{s.responsibleConsultant?.name ?? 'Consultor removido'}</td>
                    <td className={styles.tdCenter}>{s.participantCount ?? '—'}</td>
                    <td><StatusBadge status={s.status} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  )
}
