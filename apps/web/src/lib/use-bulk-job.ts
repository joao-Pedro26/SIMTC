'use client'

import { useEffect, useState } from 'react'
import { clientApi } from '@/lib/client-api'

export type BulkJobKind = 'DELETE_PARTICIPANTS' | 'SEND_CERTIFICATES' | 'DOWNLOAD_ZIP' | 'GENERATE_DOCUMENTS'
export type BulkJobStatus = 'PENDING' | 'RUNNING' | 'COMPLETED' | 'FAILED'

export interface BulkItemResult {
  participantId: string
  name: string
  status: 'success' | 'skipped' | 'failed'
  reason?: string
}

export interface BulkJob {
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

const POLL_INTERVAL_MS = 1500

export function isBulkJobFinished(job: BulkJob | null): boolean {
  return !!job && (job.status === 'COMPLETED' || job.status === 'FAILED')
}

/**
 * Acompanha um job em lote por polling em GET /jobs/:jobId a cada ~1,5 s,
 * até ele chegar a COMPLETED ou FAILED. Com `jobId` nulo não faz nada.
 * Usado pelo BulkJobProgressModal e pela aba Documentos, que acompanha a
 * geração com o modal fechado.
 */
export function useBulkJob(jobId: string | null): { job: BulkJob | null; pollError: string } {
  const [job, setJob] = useState<BulkJob | null>(null)
  const [pollError, setPollError] = useState('')

  useEffect(() => {
    setJob(null)
    setPollError('')
    if (!jobId) return

    let cancelled = false
    let timer: ReturnType<typeof setTimeout>

    async function poll() {
      try {
        const data = await clientApi.get<BulkJob>(`/jobs/${jobId}`)
        if (cancelled) return
        setJob(data)
        setPollError('')
        if (isBulkJobFinished(data)) return
      } catch (e) {
        if (cancelled) return
        setPollError(e instanceof Error ? e.message : 'Erro ao consultar progresso do processo')
      }
      timer = setTimeout(poll, POLL_INTERVAL_MS)
    }

    poll()
    return () => {
      cancelled = true
      clearTimeout(timer)
    }
  }, [jobId])

  return { job, pollError }
}
