'use client'

import Image from 'next/image'
import { User, Building2, CalendarDays } from 'lucide-react'
import styles from './demand-card.module.css'

export interface Demand {
  id: string
  companyId: string
  companyName: string
  companyLogoUrl?: string | null
  consultantId: string
  consultantName: string
  courseId: string
  courseType: string
  notes?: string | null
  participantCount?: number | null
  status: 'QUALIFICACAO' | 'ANALISE' | 'AGENDAMENTO'
  createdAt: string
  updatedAt: string
}

interface DemandCardProps {
  demand: Demand
  onClick?: () => void
}

function getAgingDays(createdAt: string): number {
  const created = new Date(createdAt)
  const now = new Date()
  return Math.floor((now.getTime() - created.getTime()) / (1000 * 60 * 60 * 24))
}

function AgingBadge({ days }: { days: number }) {
  const cls =
    days >= 30 ? styles.agingHigh : days >= 14 ? styles.agingMid : styles.agingLow
  const label = days === 0 ? 'Hoje' : days === 1 ? '1d' : `${days}d`
  return <span className={`${styles.aging} ${cls}`}>{label}</span>
}

function CompanyInitials({ name }: { name: string }) {
  const words = name.trim().split(/\s+/)
  const initials =
    words.length >= 2
      ? (words[0][0] + words[1][0]).toUpperCase()
      : name.slice(0, 2).toUpperCase()
  return <span className={styles.initials}>{initials}</span>
}

function formatDate(iso: string) {
  const d = new Date(iso)
  return d.toLocaleDateString('pt-BR')
}

export function DemandCard({ demand, onClick }: DemandCardProps) {
  const agingDays = getAgingDays(demand.createdAt)

  return (
    <div className={styles.card} onClick={onClick}>

      {/* Logo + título + aging */}
      <div className={styles.header}>
        <div className={styles.logoWrapper}>
          {demand.companyLogoUrl ? (
            <Image
              src={demand.companyLogoUrl}
              alt={demand.companyName}
              fill
              unoptimized
              style={{ objectFit: 'contain', padding: '0.25rem' }}
            />
          ) : (
            <CompanyInitials name={demand.companyName} />
          )}
        </div>

        <div className={styles.headerText}>
          <span className={styles.demandTitle}>{demand.companyName}</span>
          <span className={styles.courseType}>{demand.courseType}</span>
        </div>

        <AgingBadge days={agingDays} />
      </div>

      <div className={styles.divider} />

      {/* Meta: consultor, participantes, data */}
      <div className={styles.meta}>
        <div className={styles.metaRow}>
          <User size={12} className={styles.metaIcon} />
          <span className={styles.metaText}>{demand.consultantName}</span>
        </div>
        {demand.participantCount != null && (
          <div className={styles.metaRow}>
            <Building2 size={12} className={styles.metaIcon} />
            <span className={styles.metaText}>{demand.participantCount} participantes</span>
          </div>
        )}
        <div className={styles.metaRow}>
          <CalendarDays size={12} className={styles.metaIcon} />
          <span className={styles.metaText}>{formatDate(demand.updatedAt)}</span>
        </div>
      </div>

      {demand.notes && (
        <p className={styles.notes}>{demand.notes}</p>
      )}

    </div>
  )
}
