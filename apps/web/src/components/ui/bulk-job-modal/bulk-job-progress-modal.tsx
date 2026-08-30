'use client'

import { useEffect, useRef, useState } from 'react'
import { Loader2, CheckCircle2, XCircle, MinusCircle, Download } from 'lucide-react'
import { Button } from '@/components/ui/button/button'
import { clientApi } from '@/lib/client-api'
import styles from './bulk-job-progress-modal.module.css'

export type BulkJobKind = 'DELETE_PARTICIPANTS' | 'SEND_CERTIFICATES' | 'DOWNLOAD_ZIP'
type BulkJobStatus = 'PENDING' | 'RUNNING' | 'COMPLETED' | 'FAILED'

interface BulkItemResult {
  participantId: string
  name: string
  status: 'success' | 'skipped' | 'failed'
  reason?: string
}

interface BulkJob {
  id: string
  type: BulkJobKind
  status: BulkJobStatus
  totalItems: number
  processedItems: number
  succeededItems: number
  skippedItems: number
  failedItems: number
  resultDetails: BulkItemResult[] | null
  errorMessage: string | null
}

interface BulkJobProgressModalProps {
  jobId: string
  title: string
  /** Chamado uma única vez quando o job chega a COMPLETED ou FAILED. */
  onFinished?: () => void
  onClose: () => void
}

const POLL_INTERVAL_MS = 1500

/**
 * Modal genérico de acompanhamento de um job em lote (excluir participantes,
 * enviar certificados por e-mail, gerar ZIP), com polling em
 * GET /jobs/:jobId a cada ~1.5s. Enquanto o job está PENDING/RUNNING, o botão
 * de fechar fica desabilitado para deixar claro que o processo ainda está em
 * andamento (pode levar alguns instantes em lotes grandes).
 *
 * Ver brainstorm-acoes-lote-participantes.md.
 */
export function BulkJobProgressModal({ jobId, title, onFinished, onClose }: BulkJobProgressModalProps) {
  const [job, setJob] = useState<BulkJob | null>(null)
  const [pollError, setPollError] = useState('')
  const [downloading, setDownloading] = useState(false)
  const finishedFiredRef = useRef(false)

  useEffect(() => {
    let cancelled = false
    let timer: ReturnType<typeof setTimeout>

    async function poll() {
      try {
        const data = await clientApi.get<BulkJob>(`/jobs/${jobId}`)
        if (cancelled) return
        setJob(data)
        setPollError('')

        if (data.status === 'COMPLETED' || data.status === 'FAILED') {
          if (!finishedFiredRef.current) {
            finishedFiredRef.current = true
            onFinished?.()
          }
          return
        }
        timer = setTimeout(poll, POLL_INTERVAL_MS)
      } catch (e) {
        if (cancelled) return
        setPollError(e instanceof Error ? e.message : 'Erro ao consultar progresso do processo')
        timer = setTimeout(poll, POLL_INTERVAL_MS)
      }
    }

    poll()
    return () => {
      cancelled = true
      clearTimeout(timer)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [jobId])

  const isRunning = !job || job.status === 'PENDING' || job.status === 'RUNNING'
  const percent = job && job.totalItems > 0 ? Math.round((job.processedItems / job.totalItems) * 100) : 0

  async function handleDownload() {
    setDownloading(true)
    setPollError('')
    try {
      await clientApi.downloadFile(`/jobs/${jobId}/download`, `documentos-${jobId}.zip`)
    } catch (e) {
      setPollError(e instanceof Error ? e.message : 'Erro ao baixar arquivo ZIP')
    } finally {
      setDownloading(false)
    }
  }

  return (
    <div className={styles.overlay} role="dialog" aria-modal="true" aria-labelledby="bulk-job-title">
      <div className={styles.dialog}>
        <h2 id="bulk-job-title" className={styles.title}>{title}</h2>

        {isRunning ? (
          <>
            <div className={styles.progressRow}>
              <Loader2 size={16} className={styles.spinner} />
              <span className={styles.progressText}>
                {job ? `${job.processedItems} de ${job.totalItems} processado(s)` : 'Iniciando...'}
              </span>
            </div>
            <div className={styles.progressBarTrack}>
              <div className={styles.progressBarFill} style={{ width: `${percent}%` }} />
            </div>
            <p className={styles.note}>Isso pode levar alguns instantes — não feche esta janela.</p>
          </>
        ) : (
          <>
            <div className={styles.summaryRow}>
              <span className={styles.summaryOk}>
                <CheckCircle2 size={14} /> {job.succeededItems} concluído(s)
              </span>
              {job.skippedItems > 0 && (
                <span className={styles.summaryWarn}>
                  <MinusCircle size={14} /> {job.skippedItems} pulado(s)
                </span>
              )}
              {job.failedItems > 0 && (
                <span className={styles.summaryFail}>
                  <XCircle size={14} /> {job.failedItems} com erro
                </span>
              )}
            </div>

            {job.status === 'FAILED' && job.errorMessage && (
              <p className={styles.jobError}>{job.errorMessage}</p>
            )}

            {job.resultDetails && job.resultDetails.length > 0 && (
              <div className={styles.itemList}>
                {job.resultDetails.map((r) => (
                  <div key={r.participantId} className={styles.item}>
                    {r.status === 'success' && <CheckCircle2 size={13} className={styles.itemIconOk} />}
                    {r.status === 'skipped' && <MinusCircle size={13} className={styles.itemIconWarn} />}
                    {r.status === 'failed' && <XCircle size={13} className={styles.itemIconFail} />}
                    <span className={styles.itemName}>{r.name}</span>
                    {r.reason && <span className={styles.itemReason}>{r.reason}</span>}
                  </div>
                ))}
              </div>
            )}
          </>
        )}

        {pollError && <p className={styles.jobError}>{pollError}</p>}

        <div className={styles.actions}>
          {!isRunning && job?.type === 'DOWNLOAD_ZIP' && job.status === 'COMPLETED' && (
            <Button variant="secondary" size="sm" onClick={handleDownload} disabled={downloading}>
              {downloading
                ? <Loader2 size={14} className={styles.spinner} />
                : <Download size={14} />
              } Baixar ZIP
            </Button>
          )}
          <Button variant={isRunning ? 'ghost' : 'primary'} size="sm" onClick={onClose} disabled={isRunning}>
            Fechar
          </Button>
        </div>
      </div>
    </div>
  )
}
