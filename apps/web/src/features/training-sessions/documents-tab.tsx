'use client'

import { useState } from 'react'
import { FileText, Send, Download, Loader2 } from 'lucide-react'
import { Button } from '@/components/ui/button/button'
import { clientApi } from '@/lib/client-api'
import { useToast } from '@/components/ui/toast/toast-provider'
import { useBulkSelection } from '@/lib/use-bulk-selection'
import { BulkJobProgressModal } from '@/components/ui/bulk-job-modal/bulk-job-progress-modal'
import type { TrainingSession } from './types'
import styles from './documents-tab.module.css'

interface DocumentsTabProps {
  session: TrainingSession
  sessionId: string
  onRefresh: () => Promise<void>
  readOnly?: boolean
}

export function DocumentsTab({ session, sessionId, onRefresh, readOnly }: DocumentsTabProps) {
  const toast = useToast()
  const [generating, setGenerating] = useState(false)
  const [generateError, setGenerateError] = useState('')
  const [sendingId, setSendingId] = useState<string | null>(null)
  const [sentIds, setSentIds] = useState<Set<string>>(new Set())
  const [downloadingId, setDownloadingId] = useState<string | null>(null)

  const allParticipantIds = session.participants.map((p) => p.id)
  const bulkSelection = useBulkSelection(allParticipantIds)
  const [bulkBusy, setBulkBusy] = useState(false)
  const [bulkJobId, setBulkJobId] = useState<string | null>(null)
  const [bulkJobTitle, setBulkJobTitle] = useState('')

  if (session.status !== 'CONCLUIDO') {
    return (
      <div className={styles.locked}>
        <FileText size={48} strokeWidth={1} className={styles.lockedIcon} />
        <p className={styles.lockedTitle}>Documentação indisponível</p>
        <p className={styles.lockedDesc}>
          Conclua o treinamento na aba &quot;Participantes&quot; para habilitar a geração de certificados.
        </p>
      </div>
    )
  }

  async function handleGenerateAll() {
    setGenerating(true)
    setGenerateError('')
    try {
      await Promise.all([
        clientApi.post(`/training-sessions/${sessionId}/generate-certificates`, {}),
        clientApi.post(`/training-sessions/${sessionId}/generate-assessment-reports`, {}),
      ])
      await onRefresh()
      toast.success('Certificados e relatórios de avaliação gerados.')
    } catch (e) {
      setGenerateError(e instanceof Error ? e.message : 'Erro ao gerar documentos')
    } finally {
      setGenerating(false)
    }
  }

  async function handleDownload(certificateId: string) {
    setDownloadingId(certificateId)
    try {
      const { url } = await clientApi.get<{ url: string }>(`/certificates/${certificateId}/download-url`)
      window.open(url, '_blank', 'noopener,noreferrer')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao baixar certificado.')
    } finally {
      setDownloadingId(null)
    }
  }

  async function handleSend(certificateId: string) {
    setSendingId(certificateId)
    try {
      await clientApi.post(`/certificates/${certificateId}/send`, { to: 'participant' })
      setSentIds((prev) => new Set(prev).add(certificateId))
      toast.success('Certificado enviado por e-mail.')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao enviar certificado.')
    } finally {
      setSendingId(null)
    }
  }

  async function handleBulkSend() {
    setBulkBusy(true)
    setGenerateError('')
    try {
      const { jobId } = await clientApi.post<{ jobId: string }>(
        `/training-sessions/${sessionId}/participants/bulk-send-certificates`,
        { participantIds: bulkSelection.selectedIds },
      )
      setBulkJobTitle('Enviando certificados e relatórios por e-mail')
      setBulkJobId(jobId)
    } catch (e) {
      setGenerateError(e instanceof Error ? e.message : 'Erro ao iniciar envio em lote')
    } finally {
      setBulkBusy(false)
    }
  }

  async function handleBulkZip() {
    setBulkBusy(true)
    setGenerateError('')
    try {
      const { jobId } = await clientApi.post<{ jobId: string }>(
        `/training-sessions/${sessionId}/participants/bulk-download`,
        { participantIds: bulkSelection.selectedIds },
      )
      setBulkJobTitle('Gerando arquivo ZIP')
      setBulkJobId(jobId)
    } catch (e) {
      setGenerateError(e instanceof Error ? e.message : 'Erro ao iniciar geração do ZIP')
    } finally {
      setBulkBusy(false)
    }
  }

  return (
    <div className={styles.wrapper}>
      <div className={styles.toolbar}>
        <p className={styles.summary}>
          {session.participants.filter((p) => p.certificateGenerated).length} / {session.participants.length} certificados gerados
        </p>
        <div className={styles.toolbarActions}>
          {bulkSelection.selectedCount > 0 && (
            <>
              {!readOnly && (
                <Button variant="secondary" size="sm" onClick={handleBulkSend} disabled={bulkBusy}>
                  <Send size={14} /> Enviar selecionados ({bulkSelection.selectedCount})
                </Button>
              )}
              <Button variant="secondary" size="sm" onClick={handleBulkZip} disabled={bulkBusy}>
                <Download size={14} /> Baixar ZIP ({bulkSelection.selectedCount})
              </Button>
            </>
          )}
          {!readOnly && (
            <Button variant="primary" size="sm" onClick={handleGenerateAll} disabled={generating}>
              {generating
                ? <><Loader2 size={14} style={{ animation: 'spin 1s linear infinite' }} /> Gerando...</>
                : <><FileText size={14} /> Gerar Documentos</>
              }
            </Button>
          )}
        </div>
      </div>

      {generateError && (
        <p style={{ color: '#e53e3e', fontSize: '0.8125rem', marginBottom: '0.75rem' }}>
          {generateError}
        </p>
      )}

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
              <th className={styles.th}>Nome</th>
              <th className={`${styles.th} ${styles.center}`}>Tipo</th>
              <th className={`${styles.th} ${styles.center}`}>Score</th>
              <th className={`${styles.th} ${styles.center}`}>Certificado</th>
              <th className={styles.th} />
            </tr>
          </thead>
          <tbody>
            {session.participants.map((p) => (
              <tr key={p.id} className={styles.row}>
                <td className={styles.td}>
                  <input
                    type="checkbox"
                    checked={bulkSelection.isSelected(p.id)}
                    onChange={() => bulkSelection.toggle(p.id)}
                    aria-label={`Selecionar ${p.name}`}
                  />
                </td>
                <td className={styles.td}>{p.name}</td>
                <td className={`${styles.td} ${styles.center}`}>
                  {p.type === 'SOMENTE_TEORICA' ? 'Teoria' : 'Teoria + Prática'}
                </td>
                <td className={`${styles.td} ${styles.center}`}>
                  {p.score !== null
                    ? (
                      <span className={p.score >= 70 ? styles.scoreOk : styles.scoreFail}>
                        {p.score.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}%
                      </span>
                    )
                    : <span className={styles.scoreDash}>—</span>
                  }
                </td>
                <td className={`${styles.td} ${styles.center}`}>
                  {p.certificateGenerated
                    ? <span className={styles.certGenerated}>Gerado</span>
                    : <span className={styles.certPending}>Pendente</span>
                  }
                </td>
                <td className={styles.td}>
                  <div className={styles.rowActions}>
                    {p.certificateGenerated && p.certificateId && (
                      <>
                        <button
                          className={styles.actionBtn}
                          onClick={() => handleDownload(p.certificateId!)}
                          disabled={downloadingId === p.certificateId}
                          title="Baixar certificado PDF"
                        >
                          {downloadingId === p.certificateId
                            ? <Loader2 size={14} style={{ animation: 'spin 1s linear infinite' }} />
                            : <Download size={14} />
                          }
                        </button>
                        {sentIds.has(p.certificateId) ? (
                          <span className={styles.sentLabel}>Enviado ✓</span>
                        ) : !readOnly ? (
                          <button
                            className={styles.actionBtn}
                            onClick={() => handleSend(p.certificateId!)}
                            disabled={sendingId === p.certificateId}
                            title="Enviar por e-mail"
                          >
                            {sendingId === p.certificateId
                              ? <Loader2 size={14} style={{ animation: 'spin 1s linear infinite' }} />
                              : <Send size={14} />
                            }
                          </button>
                        ) : null}
                      </>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {bulkJobId && (
        <BulkJobProgressModal
          jobId={bulkJobId}
          title={bulkJobTitle}
          onFinished={() => {
            bulkSelection.clear()
            onRefresh()
          }}
          onClose={() => setBulkJobId(null)}
        />
      )}
    </div>
  )
}
