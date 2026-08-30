'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { Download } from 'lucide-react'
import { Button } from '@/components/ui/button/button'
import { Drawer } from '@/components/ui/drawer/drawer'
import { clientApi } from '@/lib/client-api'
import { formatCpf } from '@/lib/utils'
import { useBulkSelection } from '@/lib/use-bulk-selection'
import { BulkJobProgressModal } from '@/components/ui/bulk-job-modal/bulk-job-progress-modal'
import styles from './training-detail.module.css'
import type { ParticipantStatus, SessionParticipant, AssessmentReportRow, CertificateRow, SessionDetail } from './types'

interface Props {
  session: SessionDetail
  reportRows: AssessmentReportRow[]
  certRows: CertificateRow[]
}

type Tab = 'participants' | 'documents'

const tabs: { id: Tab; label: string }[] = [
  { id: 'participants', label: 'Participantes' },
  { id: 'documents',    label: 'Documentos' },
]

const statusLabels: Record<ParticipantStatus, string> = {
  PENDENTE:              'Pendente',
  EM_AVALIACAO:          'Em Avaliação',
  APROVADO:              'Aprovado',
  NECESSITA_REAVALIACAO: 'Necessita Reavaliação',
}

const statusCssMap: Record<ParticipantStatus, string> = {
  PENDENTE:              styles.statusPendente,
  EM_AVALIACAO:          styles.statusEmAvaliacao,
  APROVADO:              styles.statusAprovado,
  NECESSITA_REAVALIACAO: styles.statusNecessita,
}

/**
 * Status "visual": quando está EM_AVALIACAO mas já existe um assessment anterior,
 * trata-se de uma reavaliação em andamento — mantém o badge como "Necessita Reavaliação"
 * em vez de mostrar "Em Avaliação".
 */
function getDisplayStatus(p: { status: ParticipantStatus; assessment?: { score: number | null } | null }): ParticipantStatus {
  if (p.status === 'EM_AVALIACAO' && p.assessment != null) return 'NECESSITA_REAVALIACAO'
  return p.status
}

function formatDate(dateStr?: string | null): string {
  if (!dateStr) return '—'
  return new Date(dateStr).toLocaleDateString('pt-BR')
}

/** Uma linha por participante, com relatório e certificado combinados (aba "Documentos"). */
interface DocumentRow {
  participantId: string
  participantName: string
  status: ParticipantStatus
  assessmentReport: AssessmentReportRow['assessmentReport']
  certificate: CertificateRow['certificate']
}

function mergeDocumentRows(reportRows: AssessmentReportRow[], certRows: CertificateRow[]): DocumentRow[] {
  const byParticipant = new Map<string, DocumentRow>()

  for (const r of reportRows) {
    byParticipant.set(r.participantId, {
      participantId: r.participantId,
      participantName: r.participantName,
      status: r.status,
      assessmentReport: r.assessmentReport,
      certificate: null,
    })
  }

  for (const c of certRows) {
    const existing = byParticipant.get(c.participantId)
    if (existing) {
      existing.certificate = c.certificate
    } else {
      byParticipant.set(c.participantId, {
        participantId: c.participantId,
        participantName: c.participantName,
        status: c.status,
        assessmentReport: null,
        certificate: c.certificate,
      })
    }
  }

  return Array.from(byParticipant.values())
}

export function TrainingDetailClient({ session, reportRows, certRows }: Props) {
  const [activeTab, setActiveTab] = useState<Tab>('participants')
  const [downloadingId, setDownloadingId] = useState<string | null>(null)
  const [toast, setToast] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  function showToast(msg: string) {
    setToast(msg)
    setTimeout(() => setToast(null), 3000)
  }

  async function handleDownloadReport(assessmentId: string) {
    setDownloadingId(assessmentId)
    setError(null)
    try {
      const { url } = await clientApi.get<{ url: string }>(
        `/assessment-reports/${assessmentId}/download-url`,
      )
      window.open(url, '_blank', 'noopener,noreferrer')
      showToast('Download iniciado.')
    } catch (err: any) {
      setError(err.message ?? 'Erro ao gerar link de download')
    } finally {
      setDownloadingId(null)
    }
  }

  async function handleDownloadCert(certId: string) {
    setDownloadingId(certId)
    setError(null)
    try {
      const { url } = await clientApi.get<{ url: string }>(
        `/certificates/${certId}/download-url`,
      )
      window.open(url, '_blank', 'noopener,noreferrer')
      showToast('Download iniciado.')
    } catch (err: any) {
      setError(err.message ?? 'Erro ao gerar link de download')
    } finally {
      setDownloadingId(null)
    }
  }

  return (
    <div className={styles.page}>
      {toast && <div className={styles.toast}>{toast}</div>}

      <Link href="/my-company" className={styles.breadcrumb}>← Minha Empresa</Link>

      <div className={styles.header}>
        <div className={styles.titleBlock}>
          <h1 className={styles.courseName}>{session.course.name}</h1>
          <span className={styles.meta}>
            {session.city}/{session.state}
            {session.date ? ` · ${formatDate(session.date)}` : ''}
          </span>
        </div>
      </div>

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

      {error && <p className={styles.error}>{error}</p>}

      {activeTab === 'participants' && (
        <ParticipantsTab sessionId={session.id} participants={session.participants} />
      )}

      {activeTab === 'documents' && (
        <DocumentsTab
          reportRows={reportRows}
          certRows={certRows}
          downloadingId={downloadingId}
          onDownloadReport={handleDownloadReport}
          onDownloadCert={handleDownloadCert}
        />
      )}
    </div>
  )
}

function ParticipantsTab({ sessionId, participants }: { sessionId: string; participants: SessionParticipant[] }) {
  const router = useRouter()
  // Importante: usar tp.id (PK da matrícula/TrainingParticipant), não tp.participantId
  // (que é a FK para Participant.id) — o backend de ações em lote espera o ID da matrícula.
  const allParticipantIds = participants.map((tp) => tp.id)
  const bulkSelection = useBulkSelection(allParticipantIds)
  const [bulkBusy, setBulkBusy] = useState(false)
  const [bulkJobId, setBulkJobId] = useState<string | null>(null)
  const [bulkError, setBulkError] = useState('')
  const [selected, setSelected] = useState<SessionParticipant | null>(null)

  async function handleBulkZip() {
    setBulkBusy(true)
    setBulkError('')
    try {
      const { jobId } = await clientApi.post<{ jobId: string }>(
        `/training-sessions/${sessionId}/participants/bulk-download`,
        { participantIds: bulkSelection.selectedIds },
      )
      setBulkJobId(jobId)
    } catch (e) {
      setBulkError(e instanceof Error ? e.message : 'Erro ao iniciar geração do ZIP')
    } finally {
      setBulkBusy(false)
    }
  }

  if (participants.length === 0) {
    return <p className={styles.empty}>Nenhum participante registrado.</p>
  }

  return (
    <div>
      <div className={styles.bulkToolbar}>
        {bulkSelection.selectedCount > 0 && (
          <Button variant="secondary" size="sm" onClick={handleBulkZip} disabled={bulkBusy}>
            <Download size={14} /> Baixar certificados e relatórios selecionados ({bulkSelection.selectedCount})
          </Button>
        )}
      </div>

      {bulkError && <p className={styles.error}>{bulkError}</p>}

      <div className={styles.tableWrapper}>
        <table className={styles.table}>
          <thead>
            <tr className={styles.headRow}>
              <th className={styles.th} style={{ width: '2rem' }}>
                <input
                  type="checkbox"
                  checked={bulkSelection.allSelected}
                  ref={(el) => { if (el) el.indeterminate = bulkSelection.someSelected }}
                  onChange={bulkSelection.toggleAll}
                  aria-label="Selecionar todos os participantes"
                />
              </th>
              <th className={styles.th}>Participante</th>
              <th className={`${styles.th} ${styles.thCenter}`}>Status</th>
              <th className={`${styles.th} ${styles.thCenter}`}>Pontuação</th>
            </tr>
          </thead>
          <tbody>
            {participants.map((tp) => {
              const displayStatus = getDisplayStatus(tp)
              return (
              <tr
                key={tp.id}
                className={styles.row}
                onClick={() => setSelected(tp)}
                style={{ cursor: 'pointer' }}
              >
                <td className={styles.td} onClick={(e) => e.stopPropagation()}>
                  <input
                    type="checkbox"
                    checked={bulkSelection.isSelected(tp.id)}
                    onChange={() => bulkSelection.toggle(tp.id)}
                    aria-label={`Selecionar ${tp.participant.name}`}
                  />
                </td>
                <td className={styles.td}>{tp.participant.name}</td>
                <td className={`${styles.td} ${styles.tdCenter}`}>
                  <span className={`${styles.statusBadge} ${statusCssMap[displayStatus]}`}>
                    {statusLabels[displayStatus]}
                  </span>
                </td>
                <td className={`${styles.td} ${styles.tdCenter}`}>
                  {tp.assessment?.score != null ? (
                    <span className={styles.scoreHint}>
                      {Math.round(tp.assessment.score)}%
                    </span>
                  ) : (
                    <span className={styles.muted}>—</span>
                  )}
                </td>
              </tr>
            )})}
          </tbody>
        </table>
      </div>

      {bulkJobId && (
        <BulkJobProgressModal
          jobId={bulkJobId}
          title="Gerando arquivo ZIP"
          onFinished={() => {
            bulkSelection.clear()
            router.refresh()
          }}
          onClose={() => setBulkJobId(null)}
        />
      )}

      {selected && (
        <ParticipantDrawer participant={selected} onClose={() => setSelected(null)} />
      )}
    </div>
  )
}

function ParticipantDrawer({ participant, onClose }: { participant: SessionParticipant; onClose: () => void }) {
  const p = participant.participant
  const displayStatus = getDisplayStatus(participant)

  return (
    <Drawer open title={p.name} onClose={onClose} maxWidth="28rem">
      <div className={styles.detailList}>
        <div className={styles.detailRow}>
          <span className={styles.detailLabel}>E-mail</span>
          <span className={styles.detailValue}>{p.email ?? '—'}</span>
        </div>
        <div className={styles.detailRow}>
          <span className={styles.detailLabel}>CPF</span>
          <span className={styles.detailValue}>{formatCpf(p.cpf)}</span>
        </div>
        <div className={styles.detailRow}>
          <span className={styles.detailLabel}>Categoria de CNH</span>
          <span className={styles.detailValue}>{p.cnhCategory ?? '—'}</span>
        </div>
        <div className={styles.detailRow}>
          <span className={styles.detailLabel}>Validade da CNH</span>
          <span className={styles.detailValue}>{formatDate(p.cnhExpiration)}</span>
        </div>
        <div className={styles.detailRow}>
          <span className={styles.detailLabel}>Status</span>
          <span className={`${styles.statusBadge} ${statusCssMap[displayStatus]}`}>
            {statusLabels[displayStatus]}
          </span>
        </div>
        {participant.assessment?.score != null && (
          <div className={styles.detailRow}>
            <span className={styles.detailLabel}>Pontuação</span>
            <span className={styles.detailValue}>{Math.round(participant.assessment.score)}%</span>
          </div>
        )}
      </div>
    </Drawer>
  )
}

function DocumentsTab({
  reportRows,
  certRows,
  downloadingId,
  onDownloadReport,
  onDownloadCert,
}: {
  reportRows: AssessmentReportRow[]
  certRows: CertificateRow[]
  downloadingId: string | null
  onDownloadReport: (id: string) => void
  onDownloadCert: (id: string) => void
}) {
  const rows = mergeDocumentRows(reportRows, certRows)

  if (rows.length === 0) {
    return <p className={styles.empty}>Nenhum participante neste treinamento.</p>
  }

  return (
    <div className={styles.tableWrapper}>
      <table className={styles.table}>
        <thead>
          <tr className={styles.headRow}>
            <th className={styles.th}>Participante</th>
            <th className={`${styles.th} ${styles.thCenter}`}>Status</th>
            <th className={`${styles.th} ${styles.thCenter}`}>Relatório</th>
            <th className={`${styles.th} ${styles.thCenter}`}>Certificado</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.participantId} className={styles.row}>
              <td className={styles.td}>{row.participantName}</td>
              <td className={`${styles.td} ${styles.tdCenter}`}>
                <span className={`${styles.statusBadge} ${statusCssMap[row.status]}`}>
                  {statusLabels[row.status]}
                </span>
              </td>
              <td className={`${styles.td} ${styles.tdCenter}`}>
                <div className={styles.docCell}>
                  {row.assessmentReport ? (
                    <>
                      <span className={`${styles.statusBadge} ${styles.badgeOk}`}>Gerado</span>
                      <button
                        className={styles.downloadBtn}
                        onClick={() => onDownloadReport(row.assessmentReport!.id)}
                        disabled={downloadingId === row.assessmentReport.id}
                      >
                        {downloadingId === row.assessmentReport.id ? 'Aguarde…' : 'Baixar PDF'}
                      </button>
                    </>
                  ) : (
                    <span className={`${styles.statusBadge} ${styles.badgePending}`}>Pendente</span>
                  )}
                </div>
              </td>
              <td className={`${styles.td} ${styles.tdCenter}`}>
                <div className={styles.docCell}>
                  {row.certificate ? (
                    <>
                      <span className={`${styles.statusBadge} ${styles.badgeOk}`}>Gerado</span>
                      <button
                        className={styles.downloadBtn}
                        onClick={() => onDownloadCert(row.certificate!.id)}
                        disabled={downloadingId === row.certificate.id}
                      >
                        {downloadingId === row.certificate.id ? 'Aguarde…' : 'Baixar PDF'}
                      </button>
                    </>
                  ) : (
                    <span className={`${styles.statusBadge} ${styles.badgePending}`}>Pendente</span>
                  )}
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
