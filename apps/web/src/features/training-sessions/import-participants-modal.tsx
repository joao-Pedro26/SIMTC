'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import type { ChangeEvent, DragEvent } from 'react'
import { Loader2, Upload, Download, FileSpreadsheet } from 'lucide-react'
import {
  ParticipationType,
  type ImportParticipantsDto,
  type ParticipantImportChange,
  type ParticipantImportPreviewResponse,
  type ParticipantImportPreviewRow,
  type ParticipantImportResult,
  type ParticipantImportRowDto,
  type ParticipantImportRowStatus,
  PARTICIPANT_IMPORT_MAX_BYTES,
} from '@simtc/shared-types'
import { Button } from '@/components/ui/button/button'
import { clientApi } from '@/lib/client-api'
import { useBulkSelection } from '@/lib/use-bulk-selection'
import { formatCpf } from '@/lib/utils'
import styles from './import-participants-modal.module.css'

interface ImportParticipantsModalProps {
  sessionId: string
  onClose: () => void
  /** Chamado uma única vez, ao fechar a tela de resultado, antes de onClose. */
  onImported: () => void
}

const STATUS_LABELS: Record<ParticipantImportRowStatus, string> = {
  NOVO: 'Novo',
  ATUALIZA_E_INSCREVE: 'Atualiza cadastro',
  JA_INSCRITO: 'Já inscrito',
  DUPLICADO_NA_PLANILHA: 'Duplicado na planilha',
  ERRO: 'Erro',
}

const STATUS_CLASS: Record<ParticipantImportRowStatus, string> = {
  NOVO: styles.badgeOk,
  ATUALIZA_E_INSCREVE: styles.badgeInfo,
  JA_INSCRITO: styles.badgeMuted,
  DUPLICADO_NA_PLANILHA: styles.badgeWarn,
  ERRO: styles.badgeFail,
}

const FIELD_LABELS: Record<ParticipantImportChange['field'], string> = {
  name: 'Nome',
  email: 'E-mail',
  cnhCategory: 'Categoria CNH',
  cnhExpiration: 'Validade CNH',
}

const TYPE_LABELS: Record<ParticipationType, string> = {
  [ParticipationType.SOMENTE_TEORICA]: 'Teoria',
  [ParticipationType.TEORICA_E_PRATICA]: 'Teoria + Prática',
}

const SELECTABLE: ParticipantImportRowStatus[] = ['NOVO', 'ATUALIZA_E_INSCREVE']

function isSelectable(row: ParticipantImportPreviewRow) {
  return SELECTABLE.includes(row.status)
}

/** Remove tudo que a prévia acrescentou: o backend recusa campos extras. */
function toRowDto(row: ParticipantImportPreviewRow): ParticipantImportRowDto {
  const dto: ParticipantImportRowDto = { rowNumber: row.rowNumber, name: row.name, cpf: row.cpf }
  if (row.email !== undefined) dto.email = row.email
  if (row.cnhCategory !== undefined) dto.cnhCategory = row.cnhCategory
  if (row.cnhExpiration !== undefined) dto.cnhExpiration = row.cnhExpiration
  if (row.participationType !== undefined) dto.participationType = row.participationType
  return dto
}

export function ImportParticipantsModal({ sessionId, onClose, onImported }: ImportParticipantsModalProps) {
  const [defaultType, setDefaultType] = useState<ParticipationType>(ParticipationType.TEORICA_E_PRATICA)
  const [loadingPreview, setLoadingPreview] = useState(false)
  const [error, setError] = useState('')
  const [dragging, setDragging] = useState(false)
  const [preview, setPreview] = useState<ParticipantImportPreviewResponse | null>(null)
  const [result, setResult] = useState<ParticipantImportResult | null>(null)
  const [downloadingTemplate, setDownloadingTemplate] = useState(false)
  // A gravação pode ter alcançado o servidor mesmo que a resposta tenha falhado.
  const [importAttempted, setImportAttempted] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  async function sendFile(file: File) {
    setError('')
    if (file.size > PARTICIPANT_IMPORT_MAX_BYTES) {
      setError('O arquivo tem mais de 2 MB. Reduza a planilha ou divida em arquivos menores.')
      return
    }
    setLoadingPreview(true)
    try {
      const fd = new FormData()
      fd.append('file', file)
      const data = await clientApi.uploadPost<ParticipantImportPreviewResponse>(
        `/training-sessions/${sessionId}/participants/import/preview`,
        fd,
      )
      setPreview(data)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Não foi possível ler a planilha.')
    } finally {
      setLoadingPreview(false)
    }
  }

  function handleFileChange(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    e.target.value = ''
    if (file) void sendFile(file)
  }

  function handleDrop(e: DragEvent<HTMLDivElement>) {
    e.preventDefault()
    setDragging(false)
    if (loadingPreview) return
    const file = e.dataTransfer.files?.[0]
    if (file) void sendFile(file)
  }

  async function handleTemplate() {
    setDownloadingTemplate(true)
    setError('')
    try {
      await clientApi.downloadFile('/participants/import/template', 'modelo-importacao-participantes.xlsx')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Não foi possível baixar o modelo.')
    } finally {
      setDownloadingTemplate(false)
    }
  }

  function handleClose() {
    if (result || importAttempted) onImported()
    onClose()
  }

  return (
    <div className={styles.overlay} role="dialog" aria-modal="true" aria-labelledby="import-participants-title">
      <div className={styles.dialog}>
        <h2 id="import-participants-title" className={styles.title}>Importar participantes por planilha</h2>

        {result ? (
          <ResultStep result={result} onClose={handleClose} />
        ) : preview ? (
          <PreviewStep
            sessionId={sessionId}
            preview={preview}
            defaultType={defaultType}
            onChangeFile={() => { setPreview(null); setError('') }}
            onDone={setResult}
            onAttempt={() => setImportAttempted(true)}
            onClose={handleClose}
          />
        ) : (
          <>
            <div className={styles.body}>
              <div className={styles.field}>
                <label htmlFor="import-default-type" className={styles.label}>Tipo de participação padrão</label>
                <select
                  id="import-default-type"
                  className={styles.select}
                  value={defaultType}
                  onChange={(e) => setDefaultType(e.target.value as ParticipationType)}
                  disabled={loadingPreview}
                >
                  <option value={ParticipationType.TEORICA_E_PRATICA}>Teoria + Prática</option>
                  <option value={ParticipationType.SOMENTE_TEORICA}>Teoria</option>
                </select>
              </div>

              <div
                className={`${styles.dropzone} ${dragging ? styles.dropzoneActive : ''}`}
                onDragOver={(e) => { e.preventDefault(); setDragging(true) }}
                onDragLeave={() => setDragging(false)}
                onDrop={handleDrop}
              >
                {loadingPreview ? (
                  <>
                    <Loader2 size={28} className={styles.spinner} />
                    <p className={styles.dropText}>Lendo a planilha...</p>
                  </>
                ) : (
                  <>
                    <FileSpreadsheet size={28} className={styles.dropIcon} />
                    <p className={styles.dropText}>Arraste a planilha (.xlsx ou .csv) para cá</p>
                    <Button variant="secondary" size="sm" type="button" onClick={() => fileInputRef.current?.click()}>
                      <Upload size={14} /> Escolher arquivo
                    </Button>
                  </>
                )}
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".xlsx,.csv"
                  className={styles.srOnly}
                  aria-label="Escolher arquivo de planilha"
                  onChange={handleFileChange}
                  disabled={loadingPreview}
                />
              </div>

              <button type="button" className={styles.linkBtn} onClick={handleTemplate} disabled={downloadingTemplate}>
                <Download size={13} /> Baixar modelo
              </button>

              {error && <p className={styles.errorBox} role="alert">{error}</p>}
            </div>
            <div className={styles.actions}>
              <Button variant="ghost" size="sm" type="button" onClick={onClose}>Fechar</Button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}

interface PreviewStepProps {
  sessionId: string
  preview: ParticipantImportPreviewResponse
  defaultType: ParticipationType
  onChangeFile: () => void
  onDone: (r: ParticipantImportResult) => void
  onAttempt: () => void
  onClose: () => void
}

function PreviewStep({ sessionId, preview, defaultType, onChangeFile, onDone, onAttempt, onClose }: PreviewStepProps) {
  const [filter, setFilter] = useState<'' | ParticipantImportRowStatus>('')
  const [sending, setSending] = useState(false)
  const [error, setError] = useState('')

  const selectableIds = useMemo(
    () => preview.rows.filter(isSelectable).map((r) => String(r.rowNumber)),
    [preview],
  )
  const selection = useBulkSelection(selectableIds)

  // Todas as linhas importáveis chegam marcadas. A guarda evita desmarcar tudo
  // quando o React reexecuta o efeito (Strict Mode em desenvolvimento).
  const initializedRef = useRef(false)
  useEffect(() => {
    if (initializedRef.current) return
    initializedRef.current = true
    selection.toggleAll()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const visibleRows = filter ? preview.rows.filter((r) => r.status === filter) : preview.rows
  const { totals } = preview

  async function handleImport() {
    onAttempt()
    setSending(true)
    setError('')
    try {
      const chosen = new Set(selection.selectedIds)
      const body: ImportParticipantsDto = {
        defaultParticipationType: defaultType,
        rows: preview.rows.filter((r) => chosen.has(String(r.rowNumber))).map(toRowDto),
      }
      const res = await clientApi.post<ParticipantImportResult>(
        `/training-sessions/${sessionId}/participants/import`,
        body,
      )
      onDone(res)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Não foi possível importar os participantes.')
      setSending(false)
    }
  }

  const chips: { label: string; value: number; status: ParticipantImportRowStatus | '' }[] = [
    { label: 'Total', value: totals.total, status: '' },
    { label: STATUS_LABELS.NOVO, value: totals.novo, status: 'NOVO' },
    { label: STATUS_LABELS.ATUALIZA_E_INSCREVE, value: totals.atualizaEInscreve, status: 'ATUALIZA_E_INSCREVE' },
    { label: STATUS_LABELS.JA_INSCRITO, value: totals.jaInscrito, status: 'JA_INSCRITO' },
    { label: STATUS_LABELS.DUPLICADO_NA_PLANILHA, value: totals.duplicado, status: 'DUPLICADO_NA_PLANILHA' },
    { label: STATUS_LABELS.ERRO, value: totals.erro, status: 'ERRO' },
  ]

  return (
    <>
      <div className={styles.body}>
        <div className={styles.chips}>
          {chips.map((c) => (
            <span key={c.label} className={styles.chip}>{c.label}: <strong>{c.value}</strong></span>
          ))}
        </div>

        <div className={styles.filterRow}>
          <label htmlFor="import-status-filter" className={styles.label}>Filtrar por status</label>
          <select
            id="import-status-filter"
            className={styles.select}
            value={filter}
            onChange={(e) => setFilter(e.target.value as '' | ParticipantImportRowStatus)}
          >
            <option value="">Todos</option>
            {(Object.keys(STATUS_LABELS) as ParticipantImportRowStatus[]).map((s) => (
              <option key={s} value={s}>{STATUS_LABELS[s]}</option>
            ))}
          </select>
        </div>

        {preview.ignoredColumns.length > 0 && (
          <p className={styles.note}>Colunas ignoradas: {preview.ignoredColumns.join(', ')}</p>
        )}

        <div className={styles.tableWrap}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th className={styles.th}>
                  <input
                    type="checkbox"
                    aria-label="Selecionar todas as linhas importáveis"
                    checked={selection.allSelected}
                    ref={(el) => { if (el) el.indeterminate = selection.someSelected }}
                    onChange={selection.toggleAll}
                    disabled={selectableIds.length === 0 || sending}
                  />
                </th>
                <th className={styles.th}>Linha</th>
                <th className={styles.th}>Nome</th>
                <th className={styles.th}>CPF</th>
                <th className={styles.th}>E-mail</th>
                <th className={styles.th}>CNH</th>
                <th className={styles.th}>Tipo</th>
                <th className={styles.th}>Status</th>
              </tr>
            </thead>
            <tbody>
              {visibleRows.map((r) => {
                const id = String(r.rowNumber)
                const selectable = isSelectable(r)
                return (
                  <tr key={id} className={styles.tr}>
                    <td className={styles.td}>
                      <input
                        type="checkbox"
                        aria-label={`Selecionar linha ${r.rowNumber}`}
                        checked={selectable && selection.isSelected(id)}
                        onChange={() => selection.toggle(id)}
                        disabled={!selectable || sending}
                      />
                    </td>
                    <td className={styles.td}>{r.rowNumber}</td>
                    <td className={styles.td}>{r.name}</td>
                    <td className={styles.td}>{formatCpf(r.cpf)}</td>
                    <td className={styles.td}>{r.email ?? ''}</td>
                    <td className={styles.td}>
                      {[r.cnhCategory, r.cnhExpiration].filter(Boolean).join(' · ')}
                    </td>
                    <td className={styles.td}>{TYPE_LABELS[r.participationType ?? defaultType]}</td>
                    <td className={styles.td}>
                      <span className={`${styles.badge} ${STATUS_CLASS[r.status]}`}>{STATUS_LABELS[r.status]}</span>
                      {r.errors.map((m, i) => <p key={`e${i}`} className={styles.msgError}>{m}</p>)}
                      {r.warnings.map((m, i) => <p key={`w${i}`} className={styles.msgWarn}>{m}</p>)}
                      {r.changes?.map((c) => (
                        <p key={c.field} className={styles.msgChange}>
                          {FIELD_LABELS[c.field]}: {c.from ?? '(vazio)'} → {c.to}
                        </p>
                      ))}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>

        {error && <p className={styles.errorBox} role="alert">{error}</p>}
      </div>
      <div className={styles.actions}>
        <Button variant="ghost" size="sm" type="button" onClick={onClose} disabled={sending}>Fechar</Button>
        <Button variant="secondary" size="sm" type="button" onClick={onChangeFile} disabled={sending}>
          Trocar arquivo
        </Button>
        <Button
          variant="primary"
          size="sm"
          type="button"
          onClick={handleImport}
          disabled={selection.selectedCount === 0 || sending}
        >
          {sending && <Loader2 size={14} className={styles.spinner} />}
          Importar {selection.selectedCount} {selection.selectedCount === 1 ? 'participante' : 'participantes'}
        </Button>
      </div>
    </>
  )
}

function ResultStep({ result, onClose }: { result: ParticipantImportResult; onClose: () => void }) {
  const problems = [
    ...result.skipped.map((s) => ({ ...s, kind: 'Ignorada' })),
    ...result.failed.map((s) => ({ ...s, kind: 'Falhou' })),
  ]
  return (
    <>
      <div className={styles.body}>
        <div className={styles.chips}>
          <span className={styles.chip}>Cadastrados e inscritos: <strong>{result.created}</strong></span>
          <span className={styles.chip}>Atualizados e inscritos: <strong>{result.updatedAndEnrolled}</strong></span>
          <span className={styles.chip}>Ignoradas: <strong>{result.skipped.length}</strong></span>
          <span className={styles.chip}>Com falha: <strong>{result.failed.length}</strong></span>
        </div>
        {problems.length > 0 && (
          <ul className={styles.problemList}>
            {problems.map((p, i) => (
              <li key={`${p.kind}-${p.rowNumber}-${i}`} className={styles.problem}>
                <span>
                  {p.kind} · linha {p.rowNumber} · {formatCpf(p.cpf)}
                </span>
                <span className={styles.msgError}>{p.reason}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
      <div className={styles.actions}>
        <Button variant="primary" size="sm" type="button" onClick={onClose}>Fechar</Button>
      </div>
    </>
  )
}
