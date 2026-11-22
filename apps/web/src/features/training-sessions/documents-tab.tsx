'use client'

import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { FileText, Send, Download, Loader2, CheckCircle2, Clock } from 'lucide-react'
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
  const [downloadingRow, setDownloadingRow] = useState<string | null>(null)
  const [openMenuFor, setOpenMenuFor] = useState<string | null>(null)

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

  async function handleDownloadCertificate(rowId: string, certificateId: string) {
    setDownloadingRow(rowId)
    try {
      const { url } = await clientApi.get<{ url: string }>(`/certificates/${certificateId}/download-url`)
      window.open(url, '_blank', 'noopener,noreferrer')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao baixar certificado.')
    } finally {
      setDownloadingRow(null)
    }
  }

  async function handleDownloadReport(rowId: string, reportId: string) {
    setDownloadingRow(rowId)
    try {
      const { url } = await clientApi.get<{ url: string }>(`/assessment-reports/${reportId}/download-url`)
      window.open(url, '_blank', 'noopener,noreferrer')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao baixar relatório.')
    } finally {
      setDownloadingRow(null)
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
              <th className={`${styles.th} ${styles.center}`}>Documentos</th>
              <th className={styles.th} />
            </tr>
          </thead>
          <tbody>
            {session.participants.map((p) => {
              const hasDocs = !!(p.certificateId || p.reportId)
              return (
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
                  {hasDocs
                    ? (
                      <span className={styles.docsStatus} title="Documentos gerados" aria-label="Documentos gerados">
                        <CheckCircle2 size={16} className={styles.docsReady} />
                      </span>
                    )
                    : (
                      <span className={styles.docsStatus} title="Documentos pendentes" aria-label="Documentos pendentes">
                        <Clock size={16} className={styles.docsPending} />
                      </span>
                    )
                  }
                </td>
                <td className={styles.td}>
                  <div className={styles.rowActions}>
                    {hasDocs && (
                      <DownloadMenu
                        hasCertificate={!!p.certificateId}
                        hasReport={!!p.reportId}
                        open={openMenuFor === p.id}
                        busy={downloadingRow === p.id}
                        onToggle={() => setOpenMenuFor((cur) => (cur === p.id ? null : p.id))}
                        onClose={() => setOpenMenuFor(null)}
                        onPick={(doc) => {
                          if (doc === 'certificate' && p.certificateId) handleDownloadCertificate(p.id, p.certificateId)
                          if (doc === 'report' && p.reportId) handleDownloadReport(p.id, p.reportId)
                        }}
                      />
                    )}
                    {p.certificateGenerated && p.certificateId && (
                      <>
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
            )})}
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

type DocKind = 'certificate' | 'report'

interface DownloadMenuProps {
  hasCertificate: boolean
  hasReport: boolean
  open: boolean
  busy: boolean
  onToggle: () => void
  onClose: () => void
  onPick: (doc: DocKind) => void
}

const MENU_GAP = 4
const VIEWPORT_MARGIN = 8

/**
 * Botão de baixar com menu "Certificado" / "Relatório".
 * O menu vai para o <body> (portal) com position: fixed: a tabela tem rolagem
 * própria e o detalhe pode estar dentro de um Drawer com transform, o que
 * cortaria ou deslocaria um menu posicionado dentro da célula.
 */
function DownloadMenu({ hasCertificate, hasReport, open, busy, onToggle, onClose, onPick }: DownloadMenuProps) {
  const btnRef = useRef<HTMLButtonElement>(null)
  const menuRef = useRef<HTMLDivElement>(null)
  const [pos, setPos] = useState<{ top: number; left: number } | null>(null)

  useLayoutEffect(() => {
    if (!open) {
      setPos(null)
      return
    }
    const btn = btnRef.current
    const menu = menuRef.current
    if (!btn || !menu) return
    const r = btn.getBoundingClientRect()
    const fitsBelow = r.bottom + MENU_GAP + menu.offsetHeight <= window.innerHeight - VIEWPORT_MARGIN
    setPos({
      top: fitsBelow ? r.bottom + MENU_GAP : r.top - MENU_GAP - menu.offsetHeight,
      left: Math.max(VIEWPORT_MARGIN, r.right - menu.offsetWidth),
    })
  }, [open])

  // Menu posicionado: o foco vai para o primeiro item (teclado). preventScroll
  // porque qualquer rolagem fecha o menu.
  useEffect(() => {
    if (!open || !pos) return
    menuRef.current?.querySelector<HTMLButtonElement>('[role="menuitem"]')?.focus({ preventScroll: true })
  }, [open, pos])

  useEffect(() => {
    if (!open) return
    function focusButton() {
      btnRef.current?.focus({ preventScroll: true })
    }
    function handleMouseDown(e: MouseEvent) {
      const target = e.target as Node
      if (btnRef.current?.contains(target) || menuRef.current?.contains(target)) return
      onClose()
    }
    // Em captura e com preventDefault: o Drawer em volta ignora Esc com
    // defaultPrevented, então o Esc fecha só o menu, não o painel inteiro.
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        e.preventDefault()
        onClose()
        focusButton()
        return
      }
      const items = Array.from(menuRef.current?.querySelectorAll<HTMLButtonElement>('[role="menuitem"]') ?? [])
      const idx = items.indexOf(document.activeElement as HTMLButtonElement)
      if ((e.key === 'ArrowDown' || e.key === 'ArrowUp') && items.length > 0) {
        e.preventDefault()
        const delta = e.key === 'ArrowDown' ? 1 : -1
        const next = idx === -1 ? 0 : (idx + delta + items.length) % items.length
        items[next].focus({ preventScroll: true })
      } else if (e.key === 'Tab' && idx !== -1) {
        e.preventDefault()
        onClose()
        focusButton()
      }
    }
    document.addEventListener('mousedown', handleMouseDown)
    document.addEventListener('keydown', handleKeyDown, true)
    window.addEventListener('scroll', onClose, true)
    window.addEventListener('resize', onClose)
    return () => {
      document.removeEventListener('mousedown', handleMouseDown)
      document.removeEventListener('keydown', handleKeyDown, true)
      window.removeEventListener('scroll', onClose, true)
      window.removeEventListener('resize', onClose)
    }
  }, [open, onClose])

  function pick(doc: DocKind) {
    onClose()
    onPick(doc)
  }

  return (
    <>
      <button
        ref={btnRef}
        className={styles.actionBtn}
        onClick={onToggle}
        disabled={busy}
        title="Baixar documentos"
        aria-haspopup="menu"
        aria-expanded={open}
      >
        {busy
          ? <Loader2 size={14} style={{ animation: 'spin 1s linear infinite' }} />
          : <Download size={14} />
        }
      </button>
      {open && createPortal(
        <div
          ref={menuRef}
          role="menu"
          className={styles.menu}
          style={{ top: pos?.top ?? 0, left: pos?.left ?? 0, visibility: pos ? 'visible' : 'hidden' }}
        >
          {hasCertificate && (
            <button role="menuitem" className={styles.menuItem} onClick={() => pick('certificate')}>
              Certificado
            </button>
          )}
          {hasReport && (
            <button role="menuitem" className={styles.menuItem} onClick={() => pick('report')}>
              Relatório
            </button>
          )}
        </div>,
        document.body,
      )}
    </>
  )
}
