'use client'

import { useState } from 'react'
import { clientApi } from '@/lib/client-api'
import styles from './documents.module.css'

interface Certificate {
  id: string
  pdfUrl: string | null
  generatedAt: string | null
  sentToParticipant: boolean
  sentToCompany: boolean
}

interface CertificateRow {
  participantId: string
  participantName: string
  certificate: Certificate | null
}

interface Props {
  sessionId: string
  rows: CertificateRow[]
}

export function DocumentsClient({ sessionId, rows: initialRows }: Props) {
  const [rows, setRows] = useState(initialRows)
  const [generating, setGenerating] = useState(false)
  const [generatingReports, setGeneratingReports] = useState(false)
  const [sendingId, setSendingId] = useState<string | null>(null)
  const [downloadingId, setDownloadingId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [toast, setToast] = useState<string | null>(null)

  function showToast(msg: string) {
    setToast(msg)
    setTimeout(() => setToast(null), 3000)
  }

  async function handleDownload(certId: string) {
    setDownloadingId(certId)
    setError(null)
    try {
      const { url } = await clientApi.get<{ url: string }>(`/certificates/${certId}/download-url`)
      window.open(url, '_blank', 'noopener,noreferrer')
    } catch (err: any) {
      setError(err.message ?? 'Erro ao gerar link de download')
    } finally {
      setDownloadingId(null)
    }
  }

  async function handleGenerateReports() {
    setGeneratingReports(true)
    setError(null)
    try {
      type GenerateResult = { participantId: string; status: string; error?: string }
      const results = await clientApi.post<GenerateResult[]>(
        `/training-sessions/${sessionId}/generate-assessment-reports`,
        {},
      )

      if (results.length === 0) {
        setError('Nenhum participante com avaliação prática encontrado.')
        return
      }

      const failed = results.filter((r) => r.status === 'rejected')
      const succeeded = results.filter((r) => r.status === 'fulfilled')

      if (failed.length > 0) {
        setError(`${failed.length} relatório(s) falharam. Erro: ${failed[0].error ?? 'desconhecido'}`)
      }

      if (succeeded.length > 0) {
        showToast(`${succeeded.length} relatório(s) de avaliação gerado(s) com sucesso.`)
      }
    } catch (err: any) {
      setError(err.message ?? 'Erro ao gerar relatórios de avaliação')
    } finally {
      setGeneratingReports(false)
    }
  }

  async function handleGenerate() {
    setGenerating(true)
    setError(null)
    try {
      type GenerateResult = { participantId: string; status: string; error?: string }
      const results = await clientApi.post<GenerateResult[]>(
        `/training-sessions/${sessionId}/generate-certificates`,
        {},
      )

      if (results.length === 0) {
        setError('Nenhum participante elegível encontrado (status APROVADO ou tipo Somente Teoria).')
        return
      }

      const failed = results.filter((r) => r.status === 'rejected')
      const succeeded = results.filter((r) => r.status === 'fulfilled')

      if (failed.length > 0) {
        setError(
          `${failed.length} certificado(s) falharam. Erro: ${failed[0].error ?? 'desconhecido'}`,
        )
      }

      if (succeeded.length > 0) {
        showToast(`${succeeded.length} certificado(s) gerado(s) com sucesso.`)
        window.location.reload()
      }
    } catch (err: any) {
      setError(err.message ?? 'Erro ao gerar certificados')
    } finally {
      setGenerating(false)
    }
  }

  async function handleSend(certId: string, to: 'participant' | 'company' | 'both') {
    setSendingId(certId + to)
    setError(null)
    try {
      await clientApi.post(`/certificates/${certId}/send`, { to })
      setRows((prev) =>
        prev.map((r) => {
          if (r.certificate?.id !== certId) return r
          return {
            ...r,
            certificate: {
              ...r.certificate!,
              sentToParticipant: to === 'participant' || to === 'both' ? true : r.certificate!.sentToParticipant,
              sentToCompany: to === 'company' || to === 'both' ? true : r.certificate!.sentToCompany,
            },
          }
        })
      )
      const label = to === 'participant' ? 'participante' : to === 'company' ? 'empresa' : 'participante e empresa'
      showToast(`E-mail enviado para ${label}.`)
    } catch (err: any) {
      setError(err.message ?? 'Erro ao enviar e-mail')
    } finally {
      setSendingId(null)
    }
  }

  const generated = rows.filter((r) => r.certificate?.pdfUrl).length

  return (
    <div>
      {toast && <div className={styles.toast}>{toast}</div>}

      <div className={styles.toolbar}>
        <span className={styles.summary}>
          {generated} de {rows.length} certificado{rows.length !== 1 ? 's' : ''} gerado{generated !== 1 ? 's' : ''}
        </span>
        <div style={{ display: 'flex', gap: '0.5rem' }}>
          <button
            className={styles.generateBtn}
            style={{ background: 'var(--text-muted)', fontSize: '0.8125rem' }}
            onClick={handleGenerateReports}
            disabled={generatingReports}
            title="Gera o PDF de Avaliação Técnica para cada participante com avaliação prática"
          >
            {generatingReports ? 'Gerando…' : 'Gerar Relatórios de Avaliação'}
          </button>
          <button
            className={styles.generateBtn}
            onClick={handleGenerate}
            disabled={generating}
          >
            {generating ? 'Gerando…' : 'Gerar Certificados'}
          </button>
        </div>
      </div>

      {error && <p className={styles.error}>{error}</p>}

      <div className={styles.tableWrapper}>
        <table className={styles.table}>
          <thead>
            <tr className={styles.headRow}>
              <th className={styles.th}>Participante</th>
              <th className={`${styles.th} ${styles.center}`}>Status</th>
              <th className={`${styles.th} ${styles.center}`}>Gerado em</th>
              <th className={`${styles.th} ${styles.center}`}>Download</th>
              <th className={`${styles.th} ${styles.center}`}>Enviar por e-mail</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => {
              const cert = row.certificate
              const hasPdf = !!cert?.pdfUrl
              return (
                <tr key={row.participantId} className={styles.row}>
                  <td className={styles.td}>{row.participantName}</td>

                  <td className={`${styles.td} ${styles.center}`}>
                    {hasPdf
                      ? <span className={`${styles.badge} ${styles.badgeOk}`}>Gerado</span>
                      : <span className={`${styles.badge} ${styles.badgePending}`}>Pendente</span>}
                  </td>

                  <td className={`${styles.td} ${styles.center}`}>
                    {cert?.generatedAt
                      ? new Date(cert.generatedAt).toLocaleDateString('pt-BR')
                      : '—'}
                  </td>

                  <td className={`${styles.td} ${styles.center}`}>
                    {hasPdf ? (
                      <button
                        className={styles.downloadLink}
                        onClick={() => handleDownload(cert!.id)}
                        disabled={downloadingId === cert!.id}
                      >
                        {downloadingId === cert!.id ? 'Aguarde…' : 'Baixar PDF'}
                      </button>
                    ) : (
                      <span className={styles.muted}>—</span>
                    )}
                  </td>

                  <td className={`${styles.td} ${styles.center}`}>
                    {hasPdf ? (
                      <div className={styles.emailActions}>
                        <button
                          className={`${styles.emailBtn} ${cert!.sentToParticipant ? styles.emailBtnSent : ''}`}
                          disabled={!!sendingId}
                          onClick={() => handleSend(cert!.id, 'participant')}
                          title="Enviar para o participante"
                        >
                          {sendingId === cert!.id + 'participant' ? '…' : cert!.sentToParticipant ? '✓ Participante' : 'Participante'}
                        </button>
                        <button
                          className={`${styles.emailBtn} ${cert!.sentToCompany ? styles.emailBtnSent : ''}`}
                          disabled={!!sendingId}
                          onClick={() => handleSend(cert!.id, 'company')}
                          title="Enviar para a empresa"
                        >
                          {sendingId === cert!.id + 'company' ? '…' : cert!.sentToCompany ? '✓ Empresa' : 'Empresa'}
                        </button>
                        <button
                          className={styles.emailBtn}
                          disabled={!!sendingId}
                          onClick={() => handleSend(cert!.id, 'both')}
                          title="Enviar para ambos"
                        >
                          {sendingId === cert!.id + 'both' ? '…' : 'Ambos'}
                        </button>
                      </div>
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
    </div>
  )
}
