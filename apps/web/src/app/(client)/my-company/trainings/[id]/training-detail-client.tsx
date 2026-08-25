'use client'

import { useState } from 'react'
import { clientApi } from '@/lib/client-api'
import styles from './training-detail.module.css'
import type { ParticipantStatus, SessionParticipant, AssessmentReportRow, CertificateRow, SessionDetail } from './types'

interface Props {
  session: SessionDetail
  reportRows: AssessmentReportRow[]
  certRows: CertificateRow[]
}

type Tab = 'participants' | 'reports' | 'certificates'

const tabs: { id: Tab; label: string }[] = [
  { id: 'participants', label: 'Participantes' },
  { id: 'reports',      label: 'Relatório de Avaliação' },
  { id: 'certificates', label: 'Certificados' },
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

function formatDate(dateStr?: string | null): string {
  if (!dateStr) return '—'
  return new Date(dateStr).toLocaleDateString('pt-BR')
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
        <ParticipantsTab participants={session.participants} />
      )}

      {activeTab === 'reports' && (
        <ReportsTab
          rows={reportRows}
          downloadingId={downloadingId}
          onDownload={handleDownloadReport}
        />
      )}

      {activeTab === 'certificates' && (
        <CertificatesTab
          rows={certRows}
          downloadingId={downloadingId}
          onDownload={handleDownloadCert}
        />
      )}
    </div>
  )
}

function ParticipantsTab({ participants }: { participants: SessionParticipant[] }) {
  if (participants.length === 0) {
    return <p className={styles.empty}>Nenhum participante registrado.</p>
  }

  return (
    <div className={styles.tableWrapper}>
      <table className={styles.table}>
        <thead>
          <tr className={styles.headRow}>
            <th className={styles.th}>Participante</th>
            <th className={`${styles.th} ${styles.thCenter}`}>Status</th>
            <th className={`${styles.th} ${styles.thCenter}`}>Pontuação</th>
          </tr>
        </thead>
        <tbody>
          {participants.map((tp) => (
            <tr key={tp.participantId} className={styles.row}>
              <td className={styles.td}>{tp.participant.name}</td>
              <td className={`${styles.td} ${styles.tdCenter}`}>
                <span className={`${styles.statusBadge} ${statusCssMap[tp.status]}`}>
                  {statusLabels[tp.status]}
                </span>
              </td>
              <td className={`${styles.td} ${styles.tdCenter}`}>
                {tp.assessment?.score != null ? (
                  <span className={styles.scoreHint}>
                    {Math.round(tp.assessment.score)} pts
                  </span>
                ) : (
                  <span className={styles.muted}>—</span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function CertificatesTab({
  rows,
  downloadingId,
  onDownload,
}: {
  rows: CertificateRow[]
  downloadingId: string | null
  onDownload: (certId: string) => void
}) {
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
            <th className={`${styles.th} ${styles.thCenter}`}>Certificado</th>
            <th className={`${styles.th} ${styles.thCenter}`}>Download</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => {
            const cert = row.certificate
            return (
              <tr key={row.participantId} className={styles.row}>
                <td className={styles.td}>{row.participantName}</td>
                <td className={`${styles.td} ${styles.tdCenter}`}>
                  <span className={`${styles.statusBadge} ${statusCssMap[row.status]}`}>
                    {statusLabels[row.status]}
                  </span>
                </td>
                <td className={`${styles.td} ${styles.tdCenter}`}>
                  {cert ? (
                    <span className={`${styles.statusBadge} ${styles.badgeOk}`}>Gerado</span>
                  ) : (
                    <span className={`${styles.statusBadge} ${styles.badgePending}`}>Pendente</span>
                  )}
                </td>
                <td className={`${styles.td} ${styles.tdCenter}`}>
                  {cert ? (
                    <button
                      className={styles.downloadBtn}
                      onClick={() => onDownload(cert.id)}
                      disabled={downloadingId === cert.id}
                    >
                      {downloadingId === cert.id ? 'Aguarde…' : 'Baixar PDF'}
                    </button>
                  ) : (
                    <span className={styles.muted}>—</span>
                  )}
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}

function ReportsTab({
  rows,
  downloadingId,
  onDownload,
}: {
  rows: AssessmentReportRow[]
  downloadingId: string | null
  onDownload: (id: string) => void
}) {
  if (rows.length === 0) {
    return (
      <p className={styles.empty}>
        Nenhum participante com avaliação prática neste treinamento.
      </p>
    )
  }

  return (
    <div className={styles.tableWrapper}>
      <table className={styles.table}>
        <thead>
          <tr className={styles.headRow}>
            <th className={styles.th}>Participante</th>
            <th className={`${styles.th} ${styles.thCenter}`}>Status</th>
            <th className={`${styles.th} ${styles.thCenter}`}>Relatório</th>
            <th className={`${styles.th} ${styles.thCenter}`}>Download</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => {
            const report = row.assessmentReport
            return (
              <tr key={row.participantId} className={styles.row}>
                <td className={styles.td}>{row.participantName}</td>
                <td className={`${styles.td} ${styles.tdCenter}`}>
                  <span className={`${styles.statusBadge} ${statusCssMap[row.status]}`}>
                    {statusLabels[row.status]}
                  </span>
                </td>
                <td className={`${styles.td} ${styles.tdCenter}`}>
                  {report ? (
                    <span className={`${styles.statusBadge} ${styles.badgeOk}`}>
                      Gerado
                    </span>
                  ) : (
                    <span className={`${styles.statusBadge} ${styles.badgePending}`}>
                      Pendente
                    </span>
                  )}
                </td>
                <td className={`${styles.td} ${styles.tdCenter}`}>
                  {report ? (
                    <button
                      className={styles.downloadBtn}
                      onClick={() => onDownload(report.id)}
                      disabled={downloadingId === report.id}
                    >
                      {downloadingId === report.id ? 'Aguarde…' : 'Baixar PDF'}
                    </button>
                  ) : (
                    <span className={styles.muted}>—</span>
                  )}
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
