'use client'

import { Archive, XCircle, Settings2 } from 'lucide-react'
import { Button } from '@/components/ui/button/button'
import { TrainingSessionStatusBadge } from './training-session-status-badge'
import type { TrainingSession } from './types'
import styles from './info-tab.module.css'

interface InfoTabProps {
  session: TrainingSession
  onArchive: () => void
  onCancel: () => void
  onManage?: () => void
  readOnly?: boolean
}

function formatDate(dateStr: string): string {
  if (!dateStr) return '—'
  const [year, month, day] = dateStr.split('-')
  if (!year || !month || !day) return '—'
  return `${day}/${month}/${year}`
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className={styles.row}>
      <span className={styles.rowLabel}>{label}</span>
      <span className={styles.rowValue}>{children}</span>
    </div>
  )
}

export function InfoTab({ session, onArchive, onCancel, onManage, readOnly }: InfoTabProps) {
  const canCancel = !readOnly && (session.status === 'PLANEJADO' || session.status === 'EM_ANDAMENTO')
  const canArchive = false // Sem status ARQUIVADO no sistema

  return (
    <div className={styles.wrapper}>
      <div className={styles.content}>

        <div className={styles.companyHeader}>
          <div className={styles.logoFallback}>
            {session.company.name.split(' ').slice(0, 2).map((w) => w[0]).join('').toUpperCase()}
          </div>
          <div>
            <p className={styles.companyName}>{session.company.name}</p>
            <p className={styles.courseName}>{session.course.name}</p>
          </div>
        </div>

        <div className={styles.infoGrid}>
          <Row label="Status"><TrainingSessionStatusBadge status={session.status} /></Row>
          <Row label="Data">{formatDate(session.date)}</Row>
          <Row label="Local">{session.city} / {session.state}</Row>
          <Row label="Carga horária">
            {session.course.theoryHours}h teórica
            {session.course.practiceHours > 0 && ` + ${session.course.practiceHours}h prática`}
          </Row>
          <Row label="Nº estimado">{session.participantCount} participantes</Row>
          <Row label="Consultor responsável">{session.responsibleConsultant?.name ?? 'Consultor removido'}</Row>
          {session.additionalConsultants.length > 0 && (
            <Row label="Consultores adicionais">
              {session.additionalConsultants.map((c) => c.name).join(', ')}
            </Row>
          )}
          {session.notes && (
            <Row label="Observações">{session.notes}</Row>
          )}
        </div>

      </div>

      <div className={styles.actions}>
        <div className={styles.actionsLeft}>
          {canArchive && (
            <Button variant="ghost" size="sm" onClick={onArchive}>
              <Archive size={14} /> Arquivar
            </Button>
          )}
          {canCancel && (
            <Button variant="danger" size="sm" onClick={onCancel}>
              <XCircle size={14} /> Cancelar Treinamento
            </Button>
          )}
        </div>
        {onManage && (
          <Button variant="primary" size="sm" onClick={onManage}>
            <Settings2 size={14} /> Gerenciar Sessão
          </Button>
        )}
      </div>
    </div>
  )
}
