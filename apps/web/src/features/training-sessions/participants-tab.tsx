'use client'

import { useState } from 'react'
import { UserPlus, Upload, Check, Trash2, PenLine, Clock } from 'lucide-react'
import { Button } from '@/components/ui/button/button'
import { ColumnFilter } from '@/components/ui/column-filter/column-filter'
import { clientApi } from '@/lib/client-api'
import { formatCpf } from '@/lib/utils'
import { CNH_CATEGORIES, CPF_PATTERN } from '@/lib/validate-cpf'
import { useAddParticipantForm } from './use-add-participant-form'
import { useConfirm } from '@/components/ui/confirm-dialog/confirm-dialog-provider'
import { useToast } from '@/components/ui/toast/toast-provider'
import { useBulkSelection } from '@/lib/use-bulk-selection'
import { BulkJobProgressModal } from '@/components/ui/bulk-job-modal/bulk-job-progress-modal'
import { ImportParticipantsModal } from './import-participants-modal'
import { AssessmentTimesModal } from './assessment-times-modal'
import { assessmentTimesFromSaved } from '@/lib/assessment-times'
import type { TrainingSession, TrainingParticipant, ParticipantStatus } from './types'
import styles from './participants-tab.module.css'

interface ParticipantsTabProps {
  session: TrainingSession
  sessionId: string
  onRefresh: () => Promise<void>
  currentConsultantId?: string | null
  readOnly?: boolean
}

const statusLabels: Record<ParticipantStatus, string> = {
  PENDENTE: 'Pendente',
  EM_AVALIACAO: 'Em Avaliação',
  APROVADO: 'Aprovado',
  NAO_RECOMENDADO: 'Não Recomendado',
}

const statusColors: Record<ParticipantStatus, string> = {
  PENDENTE: styles.statusPendente,
  EM_AVALIACAO: styles.statusEmAvaliacao,
  APROVADO: styles.statusAprovado,
  NAO_RECOMENDADO: styles.statusNecessita,
}

/**
 * Status "visual": quando está EM_AVALIACAO mas já existe uma nota anterior (score),
 * trata-se de uma reavaliação em andamento — mantém o badge como "Não Recomendado"
 * em vez de mostrar "Em Avaliação".
 */
function getDisplayStatus(p: TrainingParticipant): ParticipantStatus {
  if (p.status === 'EM_AVALIACAO' && p.score != null) return 'NAO_RECOMENDADO'
  return p.status
}

/** "20/11/2026, 08:30–09:10" para o title do botão de corrigir horário */
function formatAssessmentWhen(a: NonNullable<TrainingParticipant['assessment']>): string {
  const t = assessmentTimesFromSaved(a)
  const date = t.date.split('-').reverse().join('/')
  return t.end ? `${date}, ${t.start}–${t.end}` : `${date}, ${t.start}`
}

export function ParticipantsTab({ session, sessionId, onRefresh, currentConsultantId, readOnly }: ParticipantsTabProps) {
  const confirm = useConfirm()
  const toast = useToast()
  const [showAddForm, setShowAddForm] = useState(false)
  const addForm = useAddParticipantForm(sessionId, { onEnrolled: () => void onRefresh() })
  const [busy, setBusy] = useState(false)
  const [showImport, setShowImport] = useState(false)
  const [actionError, setActionError] = useState('')
  const [nameFilter,   setNameFilter]   = useState('')
  const [tipoFilter,   setTipoFilter]   = useState('')
  const [statusFilter, setStatusFilter] = useState('')

  const canEdit = !readOnly && (session.status === 'PLANEJADO' || session.status === 'EM_ANDAMENTO')
  // Data/horário de avaliação salva: o ADMIN corrige em qualquer status,
  // inclusive com a sessão concluída (é quando os documentos são gerados).
  const canEditTimes = !readOnly
  const [timesTarget, setTimesTarget] = useState<TrainingParticipant | null>(null)

  const tipoOptions = [
    { label: 'Teoria',        value: 'SOMENTE_TEORICA'  },
    { label: 'Teoria + Prática', value: 'TEORICA_E_PRATICA' },
  ]
  const avaliacaoOptions = [
    { label: 'Pendente',              value: 'PENDENTE'              },
    { label: 'Em Avaliação',          value: 'EM_AVALIACAO'          },
    { label: 'Aprovado',              value: 'APROVADO'              },
    { label: 'Não Recomendado', value: 'NAO_RECOMENDADO' },
  ]

  const filteredParticipants = session.participants
    .filter((p) => {
      const matchName   = p.name.toLowerCase().includes(nameFilter.toLowerCase()) ||
        p.cpf.includes(nameFilter)
      const matchTipo   = tipoFilter === '' || p.type === tipoFilter
      const matchStatus = statusFilter === '' || getDisplayStatus(p) === statusFilter
      return matchName && matchTipo && matchStatus
    })
    .sort((a, b) => a.name.localeCompare(b.name, 'pt-BR', { sensitivity: 'base' }))

  // Participantes com avaliação em andamento não podem ser excluídos (mesma
  // regra do botão de excluir individual) — por isso ficam de fora da lista
  // "selecionável" para a exclusão em lote.
  const selectableIds = filteredParticipants
    .filter((p) => p.status !== 'EM_AVALIACAO')
    .map((p) => p.id)
  const bulkSelection = useBulkSelection(selectableIds)
  const [bulkJobId, setBulkJobId] = useState<string | null>(null)
  const [bulkDeleteBusy, setBulkDeleteBusy] = useState(false)

  async function run(action: () => Promise<unknown>) {
    setBusy(true)
    setActionError('')
    try {
      await action()
      await onRefresh()
    } catch (e) {
      setActionError(e instanceof Error ? e.message : 'Erro na operação')
    } finally {
      setBusy(false)
    }
  }

  async function addParticipant() {
    await run(async () => {
      await addForm.submit()
      setShowAddForm(false)
    })
  }

  async function changeType(p: TrainingParticipant) {
    const participationType = p.type === 'SOMENTE_TEORICA' ? 'TEORICA_E_PRATICA' : 'SOMENTE_TEORICA'
    await run(() => clientApi.patch(`/participants/${p.id}/type`, { participationType }))
  }

  async function removeSignature(p: TrainingParticipant) {
    const ok = await confirm({
      title: 'Remover assinatura',
      message: `Deseja remover a assinatura de ${p.name}? Os próximos certificados sairão sem ela.`,
      confirmLabel: 'Remover',
      variant: 'danger',
    })
    if (!ok) return
    setBusy(true)
    try {
      await clientApi.delete(`/participants/${p.id}/signature`)
      toast.success('Assinatura removida.')
      await onRefresh()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao remover assinatura.')
    } finally {
      setBusy(false)
    }
  }

  async function removeParticipant(id: string) {
    const ok = await confirm({
      title: 'Remover participante',
      message: 'Deseja remover este participante da sessão de treinamento?',
      confirmLabel: 'Remover',
      variant: 'danger',
    })
    if (!ok) return
    await run(() => clientApi.delete(`/participants/${id}`))
  }

  async function handleBulkDelete() {
    const ok = await confirm({
      title: 'Excluir participantes selecionados',
      message: `Deseja excluir ${bulkSelection.selectedCount} participante(s) selecionado(s)? Esta ação não pode ser desfeita.`,
      confirmLabel: 'Excluir',
      variant: 'danger',
    })
    if (!ok) return

    setBulkDeleteBusy(true)
    setActionError('')
    try {
      const { jobId } = await clientApi.post<{ jobId: string }>(
        `/training-sessions/${sessionId}/participants/bulk-delete`,
        { participantIds: bulkSelection.selectedIds },
      )
      setBulkJobId(jobId)
    } catch (e) {
      setActionError(e instanceof Error ? e.message : 'Erro ao iniciar exclusão em lote')
    } finally {
      setBulkDeleteBusy(false)
    }
  }

  const canStart = !readOnly && session.status === 'PLANEJADO'
  // Usa o status "visual" (getDisplayStatus): reavaliação-em-andamento conta como
  // NAO_RECOMENDADO para não esconder o botão de concluir o treinamento.
  const canComplete =
    !readOnly &&
    session.status === 'EM_ANDAMENTO' &&
    session.participants.length > 0 &&
    session.participants.every((p) => {
      const ds = getDisplayStatus(p)
      return p.type === 'SOMENTE_TEORICA' || ds === 'APROVADO' || ds === 'NAO_RECOMENDADO'
    })

  const totalCols = 4 + (canEdit ? 2 : 0)

  return (
    <div className={styles.wrapper}>
      <div className={styles.toolbar}>
        <p className={styles.count}>{session.participants.length} participante(s)</p>
        <div className={styles.toolbarActions}>
          {canEdit && bulkSelection.selectedCount > 0 && (
            <Button
              variant="danger"
              size="sm"
              onClick={handleBulkDelete}
              disabled={busy || bulkDeleteBusy}
            >
              <Trash2 size={14} /> Excluir selecionados ({bulkSelection.selectedCount})
            </Button>
          )}
          <Button variant="ghost" size="sm" onClick={() => setShowImport(true)} disabled={!canEdit || busy}>
            <Upload size={14} /> Importar planilha
          </Button>
          <Button
            variant="secondary"
            size="sm"
            onClick={() => setShowAddForm((v) => !v)}
            disabled={!canEdit || busy}
          >
            <UserPlus size={14} /> Adicionar manualmente
          </Button>
        </div>
      </div>

      {showAddForm && (
        <div className={styles.addForm}>
          <p className={styles.addFormTitle}>Novo Participante</p>
          <div className={styles.addFormGrid}>
            <div className={styles.field}>
              <label className={styles.label} htmlFor="add-participant-cpf">CPF *</label>
              <input
                id="add-participant-cpf"
                className={`${styles.input}${addForm.cpfError ? ` ${styles.inputInvalid}` : ''}`}
                value={addForm.values.cpf}
                onChange={(e) => addForm.setCpf(e.target.value)}
                onBlur={addForm.touchCpf}
                placeholder="000.000.000-00"
                inputMode="numeric"
                autoComplete="off"
                autoFocus
                maxLength={14}
                pattern={CPF_PATTERN}
                title="CPF no formato 000.000.000-00"
                aria-invalid={!!addForm.cpfError}
                aria-describedby="add-participant-cpf-message"
              />
              <span id="add-participant-cpf-message" aria-live="polite" className={addForm.cpfError ? styles.fieldError : styles.fieldHint}>
                {addForm.cpfError ?? addForm.cpfHelper}
              </span>
            </div>
            <div className={styles.field}>
              <label className={styles.label} htmlFor="add-participant-name">Nome *</label>
              <input id="add-participant-name" ref={addForm.nameRef} className={styles.input} value={addForm.values.name} disabled={addForm.isCheckingCpf} onChange={(e) => addForm.setField('name', e.target.value)} />
            </div>
            <div className={styles.field}>
              <label className={styles.label} htmlFor="add-participant-email">E-mail</label>
              <input id="add-participant-email" className={styles.input} type="email" value={addForm.values.email} disabled={addForm.isCheckingCpf} onChange={(e) => addForm.setField('email', e.target.value)} />
            </div>
            <div className={styles.field}>
              <label className={styles.label} htmlFor="add-participant-cnh">Cat. CNH *</label>
              <select
                id="add-participant-cnh"
                className={styles.input}
                value={addForm.values.cnhCategory}
                disabled={addForm.isCheckingCpf}
                onChange={(e) => addForm.setField('cnhCategory', e.target.value)}
              >
                <option value="">Selecione…</option>
                {CNH_CATEGORIES.map((cat) => (
                  <option key={cat} value={cat}>{cat}</option>
                ))}
              </select>
            </div>
            <div className={styles.field}>
              <label className={styles.label} htmlFor="add-participant-cnh-expiration">Vencimento CNH *</label>
              <input
                id="add-participant-cnh-expiration"
                className={`${styles.input}${addForm.expirationError ? ` ${styles.inputInvalid}` : ''}`}
                type="date"
                value={addForm.values.cnhExpiration}
                disabled={addForm.isCheckingCpf}
                onChange={(e) => addForm.setField('cnhExpiration', e.target.value)}
                onBlur={addForm.touchExpiration}
                aria-invalid={!!addForm.expirationError}
              />
              {addForm.expirationError && <span className={styles.fieldError}>{addForm.expirationError}</span>}
            </div>
          </div>
          {addForm.registryNotice && <p className={styles.registryNotice}>{addForm.registryNotice}</p>}
          <div className={styles.addFormActions}>
            <Button variant="ghost" size="sm" onClick={() => { setShowAddForm(false); addForm.reset() }}>Cancelar</Button>
            <Button
              variant="primary"
              size="sm"
              disabled={!addForm.canSubmit || busy}
              onClick={addParticipant}
            >
              <Check size={14} /> Confirmar
            </Button>
          </div>
        </div>
      )}

      {actionError && (
        <p style={{ color: 'var(--error, #c53030)', fontSize: '0.875rem', marginBottom: '0.75rem' }}>
          {actionError}
        </p>
      )}

      {session.participants.length === 0 ? (
        <p className={styles.empty}>Nenhum participante inscrito ainda.</p>
      ) : (
        <div className={styles.tableWrapper}>
          <table className={styles.table}>
            <thead>
              <tr className={styles.headRow}>
                {canEdit && (
                  <th className={styles.th} style={{ width: '2rem' }}>
                    <input
                      type="checkbox"
                      checked={bulkSelection.allSelected}
                      ref={(el) => { if (el) el.indeterminate = bulkSelection.someSelected }}
                      onChange={bulkSelection.toggleAll}
                      aria-label="Selecionar todos os participantes"
                    />
                  </th>
                )}
                <ColumnFilter
                  type="text"
                  label="Nome / CPF"
                  value={nameFilter}
                  onChange={setNameFilter}
                  className={styles.th}
                />
                <th className={styles.th}>CPF</th>
                <ColumnFilter
                  type="select"
                  label="Tipo"
                  value={tipoFilter}
                  onChange={setTipoFilter}
                  options={tipoOptions}
                  className={`${styles.th} ${styles.center}`}
                />
                <ColumnFilter
                  type="select"
                  label="Avaliação"
                  value={statusFilter}
                  onChange={setStatusFilter}
                  options={avaliacaoOptions}
                  className={`${styles.th} ${styles.center}`}
                />
                {canEdit && <th className={styles.th} />}
              </tr>
            </thead>
            <tbody>
              {filteredParticipants.length === 0 ? (
                <tr><td colSpan={totalCols} className={styles.empty}>Nenhum participante encontrado.</td></tr>
              ) : (
                filteredParticipants.map((p) => {
                  const displayStatus = getDisplayStatus(p)
                  return (
                    <tr key={p.id} className={styles.row}>
                      {canEdit && (
                        <td className={styles.td}>
                          <input
                            type="checkbox"
                            checked={bulkSelection.isSelected(p.id)}
                            disabled={p.status === 'EM_AVALIACAO'}
                            onChange={() => bulkSelection.toggle(p.id)}
                            aria-label={`Selecionar ${p.name}`}
                          />
                        </td>
                      )}
                      <td className={styles.td}>{p.name}</td>
                      <td className={styles.td}>{formatCpf(p.cpf)}</td>
                      <td className={`${styles.td} ${styles.center}`}>
                        <button
                          type="button"
                          className={`${styles.typeBtn} ${p.type === 'SOMENTE_TEORICA' ? styles.typeSoloTeoria : styles.typePratica}`}
                          onClick={() => changeType(p)}
                          disabled={!canEdit || busy}
                          title={canEdit ? 'Clique para alterar o tipo de participação' : undefined}
                          style={canEdit ? undefined : { cursor: 'default' }}
                        >
                          {p.type === 'SOMENTE_TEORICA' ? 'Teoria' : 'Teoria + Prática'}
                        </button>
                      </td>
                      <td className={`${styles.td} ${styles.center}`}>
                        <span className={`${styles.statusBadge} ${statusColors[displayStatus]}`}>
                          {statusLabels[displayStatus]}
                        </span>
                        {p.status === 'APROVADO' && p.score !== null && (
                          <span className={styles.scoreHint}> {Math.round(p.score)}%</span>
                        )}
                        {canEditTimes && p.assessment && p.status !== 'EM_AVALIACAO' && (
                          <button
                            type="button"
                            className={styles.timesBtn}
                            onClick={() => setTimesTarget(p)}
                            disabled={busy}
                            title={`Avaliação em ${formatAssessmentWhen(p.assessment)}. Clique para corrigir a data e o horário`}
                            aria-label={`Corrigir data e horário da avaliação de ${p.name}`}
                          >
                            <Clock size={14} />
                          </button>
                        )}
                      </td>
                      {canEdit && (
                        <td className={styles.td}>
                          {p.hasSignature && (
                            <button
                              className={styles.signatureBtn}
                              onClick={() => removeSignature(p)}
                              disabled={busy}
                              title="Assinatura salva. Clique para remover"
                            >
                              <PenLine size={14} />
                            </button>
                          )}
                          <button
                            className={styles.deleteBtn}
                            onClick={() => removeParticipant(p.id)}
                            disabled={busy || p.status === 'EM_AVALIACAO'}
                            title="Remover participante"
                          >
                            <Trash2 size={14} />
                          </button>
                        </td>
                      )}
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>
      )}

      <div className={styles.footer}>
        {canStart && (
          <Button variant="primary" size="sm" disabled={busy}
            onClick={() => run(() => clientApi.post(`/training-sessions/${sessionId}/start`, {}))}>
            Iniciar Treinamento
          </Button>
        )}
        {canComplete && (
          <Button variant="primary" size="sm" disabled={busy}
            onClick={() => run(() => clientApi.post(`/training-sessions/${sessionId}/complete`, {}))}>
            Concluir Treinamento
          </Button>
        )}
      </div>

      {bulkJobId && (
        <BulkJobProgressModal
          jobId={bulkJobId}
          title="Excluindo participantes selecionados"
          onFinished={() => {
            bulkSelection.clear()
            onRefresh()
          }}
          onClose={() => setBulkJobId(null)}
        />
      )}

      {timesTarget?.assessment && (
        <AssessmentTimesModal
          participantName={timesTarget.name}
          assessment={timesTarget.assessment}
          hasReport={timesTarget.reportId !== null}
          onClose={() => setTimesTarget(null)}
          onSaved={async () => {
            const hadReport = timesTarget.reportId !== null
            setTimesTarget(null)
            toast.success(
              hadReport
                ? 'Data e horário atualizados. Gere os documentos de novo para atualizar o relatório.'
                : 'Data e horário atualizados.',
            )
            await onRefresh()
          }}
        />
      )}

      {showImport && (
        <ImportParticipantsModal
          sessionId={sessionId}
          onImported={() => onRefresh()}
          onClose={() => setShowImport(false)}
        />
      )}

    </div>
  )
}
