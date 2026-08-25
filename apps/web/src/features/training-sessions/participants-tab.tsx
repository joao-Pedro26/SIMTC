'use client'

import { useState } from 'react'
import { UserPlus, Upload, Check, Trash2 } from 'lucide-react'
import { Button } from '@/components/ui/button/button'
import { ColumnFilter } from '@/components/ui/column-filter/column-filter'
import { clientApi } from '@/lib/client-api'
import { formatCpf } from '@/lib/utils'
import { useConfirm } from '@/components/ui/confirm-dialog/confirm-dialog-provider'
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
  NECESSITA_REAVALIACAO: 'Necessita Reavaliação',
}

const statusColors: Record<ParticipantStatus, string> = {
  PENDENTE: styles.statusPendente,
  EM_AVALIACAO: styles.statusEmAvaliacao,
  APROVADO: styles.statusAprovado,
  NECESSITA_REAVALIACAO: styles.statusNecessita,
}

interface AddParticipantForm {
  name: string
  cpf: string
  email: string
  cnhCategory: string
  cnhExpiration: string
}

const emptyForm: AddParticipantForm = { name: '', cpf: '', email: '', cnhCategory: '', cnhExpiration: '' }

export function ParticipantsTab({ session, sessionId, onRefresh, currentConsultantId, readOnly }: ParticipantsTabProps) {
  const confirm = useConfirm()
  const [showAddForm, setShowAddForm] = useState(false)
  const [form, setForm] = useState<AddParticipantForm>(emptyForm)
  const [busy, setBusy] = useState(false)
  const [actionError, setActionError] = useState('')
  const [nameFilter,   setNameFilter]   = useState('')
  const [tipoFilter,   setTipoFilter]   = useState('')
  const [statusFilter, setStatusFilter] = useState('')

  const canEdit = !readOnly && (session.status === 'PLANEJADO' || session.status === 'EM_ANDAMENTO')

  const tipoOptions = [
    { label: 'Só Teoria',        value: 'SOMENTE_TEORICA'  },
    { label: 'Teoria + Prática', value: 'TEORICA_E_PRATICA' },
  ]
  const avaliacaoOptions = [
    { label: 'Pendente',              value: 'PENDENTE'              },
    { label: 'Em Avaliação',          value: 'EM_AVALIACAO'          },
    { label: 'Aprovado',              value: 'APROVADO'              },
    { label: 'Necessita Reavaliação', value: 'NECESSITA_REAVALIACAO' },
  ]

  const filteredParticipants = session.participants.filter((p) => {
    const matchName   = p.name.toLowerCase().includes(nameFilter.toLowerCase()) ||
      p.cpf.includes(nameFilter)
    const matchTipo   = tipoFilter === '' || p.type === tipoFilter
    const matchStatus = statusFilter === '' || p.status === statusFilter
    return matchName && matchTipo && matchStatus
  })

  function setField(field: keyof AddParticipantForm, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }))
  }

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
    if (!form.name.trim() || !form.cpf.trim()) return
    await run(() =>
      clientApi.post(`/training-sessions/${sessionId}/participants`, {
        name: form.name.trim(),
        cpf: form.cpf.replace(/\D/g, ''),
        email: form.email.trim() || undefined,
        cnhCategory: form.cnhCategory || undefined,
        cnhExpiration: form.cnhExpiration || undefined,
      })
    )
    setForm(emptyForm)
    setShowAddForm(false)
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

  const canStart = !readOnly && session.status === 'PLANEJADO'
  const canComplete =
    !readOnly &&
    session.status === 'EM_ANDAMENTO' &&
    session.participants.length > 0 &&
    session.participants.every(
      (p) => p.type === 'SOMENTE_TEORICA' || p.status === 'APROVADO' || p.status === 'NECESSITA_REAVALIACAO'
    )

  const totalCols = 4 + (canEdit ? 1 : 0)

  return (
    <div className={styles.wrapper}>
      <div className={styles.toolbar}>
        <p className={styles.count}>{session.participants.length} participante(s)</p>
        <div className={styles.toolbarActions}>
          <Button variant="ghost" size="sm" disabled>
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
              <label className={styles.label}>Nome *</label>
              <input className={styles.input} value={form.name} onChange={(e) => setField('name', e.target.value)} />
            </div>
            <div className={styles.field}>
              <label className={styles.label}>CPF *</label>
              <input className={styles.input} value={form.cpf} onChange={(e) => setField('cpf', e.target.value)} placeholder="00000000000" />
            </div>
            <div className={styles.field}>
              <label className={styles.label}>E-mail</label>
              <input className={styles.input} type="email" value={form.email} onChange={(e) => setField('email', e.target.value)} />
            </div>
            <div className={styles.field}>
              <label className={styles.label}>Cat. CNH</label>
              <input className={styles.input} value={form.cnhCategory} onChange={(e) => setField('cnhCategory', e.target.value)} placeholder="B" />
            </div>
            <div className={styles.field}>
              <label className={styles.label}>Vencimento CNH</label>
              <input className={styles.input} type="date" value={form.cnhExpiration} onChange={(e) => setField('cnhExpiration', e.target.value)} />
            </div>
          </div>
          <div className={styles.addFormActions}>
            <Button variant="ghost" size="sm" onClick={() => { setShowAddForm(false); setForm(emptyForm) }}>Cancelar</Button>
            <Button
              variant="primary"
              size="sm"
              disabled={!form.name.trim() || !form.cpf.trim() || busy}
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
                  return (
                    <tr key={p.id} className={styles.row}>
                      <td className={styles.td}>{p.name}</td>
                      <td className={styles.td}>{formatCpf(p.cpf)}</td>
                      <td className={`${styles.td} ${styles.center}`}>
                        <span className={`${styles.typeBtn} ${p.type === 'SOMENTE_TEORICA' ? styles.typeSoloTeoria : styles.typePratica}`}>
                          {p.type === 'SOMENTE_TEORICA' ? 'Só Teoria' : 'Teoria + Prática'}
                        </span>
                      </td>
                      <td className={`${styles.td} ${styles.center}`}>
                        <span className={`${styles.statusBadge} ${statusColors[p.status]}`}>
                          {statusLabels[p.status]}
                        </span>
                        {p.status === 'APROVADO' && p.score !== null && (
                          <span className={styles.scoreHint}> {Math.round(p.score)} pts</span>
                        )}
                      </td>
                      {canEdit && (
                        <td className={styles.td}>
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

    </div>
  )
}
