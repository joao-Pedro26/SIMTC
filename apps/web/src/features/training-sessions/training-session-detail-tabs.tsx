'use client'

import { useState, useEffect, useCallback } from 'react'
import { Loader2 } from 'lucide-react'
import { InfoTab } from './info-tab'
import { ParticipantsTab } from './participants-tab'
import { QrCodeTab } from './qr-code-tab'
import { DocumentsTab } from './documents-tab'
import { clientApi } from '@/lib/client-api'
import { getSessionUser } from '@/lib/auth'
import type { TrainingSession } from './types'
import styles from './training-session-detail-tabs.module.css'

type Tab = 'info' | 'participants' | 'qrcode' | 'documents'

interface TrainingSessionDetailTabsProps {
  sessionId: string
  onSessionChanged: (updated: TrainingSession) => void
  onManage?: () => void
  readOnly?: boolean
}

interface BackendDetailSession {
  id: string
  company: { id: string; name: string; logoUrl?: string | null }
  course: { id: string; name: string; theoryHours: number; practiceHours: number }
  responsibleConsultant: { id: string; name: string } | null
  consultants?: Array<{ consultant: { id: string; name: string } }>
  city: string
  state: string
  date?: string | null
  participantCount?: number | null
  notes?: string | null
  status: TrainingSession['status']
  qrCodeToken: string
  participants?: Array<{
    id: string
    participationType: string
    status: string
    assignedConsultantId?: string | null
    assignedConsultant?: { id: string; name: string } | null
    participant: {
      id: string
      name: string
      cpf: string
      email: string
      cnhCategory?: string | null
      cnhExpiration?: string | null
    }
    assessment?: { score?: number | null } | null
    certificate?: { id: string; pdfUrl?: string | null } | null
  }>
}

function mapDetailSession(s: BackendDetailSession): TrainingSession {
  return {
    id: s.id,
    company: { id: s.company.id, name: s.company.name, logoUrl: s.company.logoUrl },
    course: {
      id: s.course.id,
      name: s.course.name,
      theoryHours: s.course.theoryHours,
      practiceHours: s.course.practiceHours,
    },
    responsibleConsultant: s.responsibleConsultant,
    additionalConsultants: (s.consultants ?? [])
      .filter((sc) => sc.consultant.id !== s.responsibleConsultant?.id)
      .map((sc) => sc.consultant),
    city: s.city,
    state: s.state,
    date: s.date ? s.date.split('T')[0] : '',
    participantCount: s.participantCount ?? 0,
    notes: s.notes ?? null,
    status: s.status,
    qrCodeToken: s.qrCodeToken,
    participants: (s.participants ?? []).map((tp) => ({
      id: tp.id,
      name: tp.participant.name,
      cpf: tp.participant.cpf,
      email: tp.participant.email,
      cnhCategory: tp.participant.cnhCategory ?? '',
      cnhExpiration: tp.participant.cnhExpiration
        ? new Date(tp.participant.cnhExpiration).toISOString().split('T')[0]
        : '',
      type: tp.participationType as TrainingSession['participants'][0]['type'],
      status: tp.status as TrainingSession['participants'][0]['status'],
      score: tp.assessment?.score ?? null,
      certificateGenerated: !!tp.certificate,
      certificateId: tp.certificate?.id ?? null,
      certificatePdfUrl: tp.certificate?.pdfUrl ?? null,
      assignedConsultantId: tp.assignedConsultantId ?? null,
      assignedConsultant: tp.assignedConsultant ?? null,
    })),
  }
}

const tabs: { id: Tab; label: string }[] = [
  { id: 'info', label: 'Informações' },
  { id: 'participants', label: 'Participantes' },
  { id: 'qrcode', label: 'QR Code' },
  { id: 'documents', label: 'Documentos' },
]

export function TrainingSessionDetailTabs({ sessionId, onSessionChanged, onManage, readOnly }: TrainingSessionDetailTabsProps) {
  const [session, setSession] = useState<TrainingSession | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [activeTab, setActiveTab] = useState<Tab>('info')

  // ID do consultor logado (para determinar quem pode avaliar quem)
  const currentUser = getSessionUser()
  const currentConsultantId = currentUser?.consultantId ?? currentUser?.id ?? null

  const fetchDetail = useCallback(async () => {
    try {
      setLoading(true)
      const data = await clientApi.get<BackendDetailSession>(`/training-sessions/${sessionId}`)
      const mapped = mapDetailSession(data)
      setSession(mapped)
      onSessionChanged(mapped)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erro ao carregar sessão')
    } finally {
      setLoading(false)
    }
  }, [sessionId, onSessionChanged])

  useEffect(() => { fetchDetail() }, [fetchDetail])

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', padding: '3rem' }}>
        <Loader2 size={28} style={{ opacity: 0.4 }} />
      </div>
    )
  }

  if (error || !session) {
    return <p style={{ color: '#e53e3e', padding: '1rem' }}>{error || 'Sessão não encontrada'}</p>
  }

  async function handleCancel() {
    await clientApi.patch(`/training-sessions/${sessionId}/cancel`, {})
    await fetchDetail()
  }

  return (
    <div className={styles.wrapper}>
      <div className={styles.tabList} role="tablist">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            role="tab"
            aria-selected={activeTab === tab.id}
            className={`${styles.tab} ${activeTab === tab.id ? styles.tabActive : ''}`}
            onClick={() => setActiveTab(tab.id)}
          >
            {tab.label}
          </button>
        ))}
      </div>
      <div className={styles.panel}>
        {activeTab === 'info' && (
          <InfoTab session={session} onArchive={() => {}} onCancel={handleCancel} onManage={onManage} readOnly={readOnly} />
        )}
        {activeTab === 'participants' && (
          <ParticipantsTab
            session={session}
            sessionId={sessionId}
            onRefresh={fetchDetail}
            currentConsultantId={currentConsultantId}
            readOnly={readOnly}
          />
        )}
        {activeTab === 'qrcode' && (
          <QrCodeTab session={session} />
        )}
        {activeTab === 'documents' && (
          <DocumentsTab session={session} sessionId={sessionId} onRefresh={fetchDetail} readOnly={readOnly} />
        )}
      </div>
    </div>
  )
}
