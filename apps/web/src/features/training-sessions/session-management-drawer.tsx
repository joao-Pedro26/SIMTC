'use client'

import { useState, useEffect, useCallback } from 'react'
import { Plus, X, Loader2, UserPlus, Check } from 'lucide-react'
import { Drawer } from '@/components/ui/drawer/drawer'
import { AssessmentDrawer } from './assessment-drawer'
import { clientApi } from '@/lib/client-api'
import { getSessionUser } from '@/lib/auth'
import { formatCpf } from '@/lib/utils'
import type { TrainingSession, TrainingConsultant, TrainingParticipant, ParticipantStatus } from './types'
import styles from './session-management-drawer.module.css'

// ── Tipos internos ─────────────────────────────────────────────────────────────

interface BackendParticipant {
  id: string
  participationType: string
  status: string
  assignedConsultantId?: string | null
  assignedConsultant?: { id: string; name: string } | null
  participant: { id: string; name: string; cpf: string; email: string; cnhCategory?: string | null; cnhExpiration?: string | null }
  assessment?: { score?: number | null } | null
}

interface BackendSession {
  id: string
  company: { id: string; name: string }
  course: { id: string; name: string; theoryHours: number; practiceHours: number }
  responsibleConsultant: { id: string; name: string } | null
  consultants?: Array<{ consultant: { id: string; name: string } }>
  city: string
  state: string
  date?: string | null
  participantCount?: number | null
  notes?: string | null
  status: string
  participants?: BackendParticipant[]
}

/**
 * Ações possíveis por participante:
 * - atribuir   → PENDENTE: apenas atribui ao consultor logado (sem abrir drawer)
 * - avaliar    → EM_AVALIACAO próprio: abre o checklist de avaliação
 * - reavaliar  → NECESSITA_REAVALIACAO: atribui + abre checklist
 * - blocked    → EM_AVALIACAO de outro consultor
 * - none       → aprovado, somente teoria, fora de EM_ANDAMENTO
 */
type AssessmentAction = 'atribuir' | 'avaliar' | 'reavaliar' | 'blocked' | 'none'

function getAction(
  p: BackendParticipant,
  consultantId: string | null | undefined,
  sessionStatus: string,
  isAdmin: boolean,
): AssessmentAction {
  if (sessionStatus !== 'EM_ANDAMENTO') return 'none'
  if (p.participationType === 'SOMENTE_TEORICA') return 'none'
  // Admin sem perfil de consultor só gerencia a sessão — não avalia
  if (isAdmin && !consultantId) return 'none'
  switch (p.status) {
    case 'PENDENTE': return 'atribuir'
    case 'EM_AVALIACAO':
      if (!consultantId) return 'none'
      return p.assignedConsultantId === consultantId ? 'avaliar' : 'blocked'
    case 'APROVADO': return 'none'
    case 'NECESSITA_REAVALIACAO': return 'reavaliar'
    default: return 'none'
  }
}

const statusLabels: Record<string, string> = {
  PENDENTE: 'Pendente',
  EM_AVALIACAO: 'Em Avaliação',
  APROVADO: 'Aprovado',
  NECESSITA_REAVALIACAO: 'Necessita Reavaliação',
}

const statusCssMap: Record<string, string> = {
  PENDENTE: styles.statusPendente,
  EM_AVALIACAO: styles.statusEmAvaliacao,
  APROVADO: styles.statusAprovado,
  NECESSITA_REAVALIACAO: styles.statusNecessita,
}

// ── Formulário de participante ─────────────────────────────────────────────────

interface ParticipantForm {
  name: string; cpf: string; email: string; cnhCategory: string; cnhExpiration: string
}
const emptyParticipantForm: ParticipantForm = { name: '', cpf: '', email: '', cnhCategory: '', cnhExpiration: '' }

// ── Props ──────────────────────────────────────────────────────────────────────

interface SessionManagementDrawerProps {
  open: boolean
  sessionId: string
  onClose: () => void
  onSaved?: () => void
}

// ── Componente ─────────────────────────────────────────────────────────────────

export function SessionManagementDrawer({ open, sessionId, onClose, onSaved }: SessionManagementDrawerProps) {
  // Dados brutos
  const [session, setSession] = useState<BackendSession | null>(null)
  const [allConsultants, setAllConsultants] = useState<TrainingConsultant[]>([])
  const [loading, setLoading] = useState(false)
  const [saveError, setSaveError] = useState('')
  const [busy, setBusy] = useState(false)

  // Usuário logado
  const currentUser = getSessionUser()
  const isAdmin = currentUser?.role === 'ADMIN'
  // Apenas o consultantId real do JWT — não usar user.id como fallback (FK aponta para Consultant, não User)
  const consultantId = currentUser?.consultantId ?? null

  // Campos editáveis
  const [date, setDate] = useState('')
  const [city, setCity] = useState('')
  const [stateField, setStateField] = useState('')
  const [notes, setNotes] = useState('')
  const [dirty, setDirty] = useState(false)

  // Gestão de colaboradores
  const [consultorToAdd, setConsultorToAdd] = useState('')
  const [consultorBusy, setConsultorBusy] = useState(false)

  // Adicionar participante
  const [showAddParticipant, setShowAddParticipant] = useState(false)
  const [participantForm, setParticipantForm] = useState<ParticipantForm>(emptyParticipantForm)
  const [participantBusy, setParticipantBusy] = useState(false)
  const [participantError, setParticipantError] = useState('')

  // Assessment drawer
  const [assessmentParticipant, setAssessmentParticipant] = useState<BackendParticipant | null>(null)
  const [assessmentOpen, setAssessmentOpen] = useState(false)

  // ── Carregamento ─────────────────────────────────────────────────────────────

  const fetchData = useCallback(async () => {
    setLoading(true)
    setSaveError('')
    try {
      const [s, consultantsRes] = await Promise.all([
        clientApi.get<BackendSession>(`/training-sessions/${sessionId}`),
        isAdmin ? clientApi.get<TrainingConsultant[]>('/consultants') : Promise.resolve([]),
      ])
      setSession(s)
      setDate(s.date ? s.date.split('T')[0] : '')
      setCity(s.city)
      setStateField(s.state)
      setNotes(s.notes ?? '')
      setDirty(false)
      if (isAdmin) setAllConsultants(consultantsRes as TrainingConsultant[])
    } catch (e) {
      setSaveError(e instanceof Error ? e.message : 'Erro ao carregar sessão')
    } finally {
      setLoading(false)
    }
  }, [sessionId, isAdmin])

  useEffect(() => {
    if (open) fetchData()
  }, [open, fetchData])

  // ── Salvar campos ─────────────────────────────────────────────────────────────

  async function handleSave() {
    if (!dirty) return
    setBusy(true)
    setSaveError('')
    try {
      await clientApi.patch(`/training-sessions/${sessionId}`, {
        date: date || undefined,
        city: city || undefined,
        state: stateField || undefined,
        notes: notes || undefined,
      })
      await fetchData()
      onSaved?.()
    } catch (e) {
      setSaveError(e instanceof Error ? e.message : 'Erro ao salvar')
    } finally {
      setBusy(false)
    }
  }

  // ── Colaboradores ─────────────────────────────────────────────────────────────

  function currentAdditionalIds(): string[] {
    if (!session) return []
    return (session.consultants ?? [])
      .map((sc) => sc.consultant.id)
      .filter((id) => id !== session.responsibleConsultant?.id)
  }

  async function handleAddConsultor() {
    if (!consultorToAdd || !session) return
    setConsultorBusy(true)
    setSaveError('')
    try {
      const additionals = Array.from(new Set([...currentAdditionalIds(), consultorToAdd]))
      await clientApi.patch(`/training-sessions/${sessionId}`, { additionalConsultantsIds: additionals })
      setConsultorToAdd('')
      await fetchData()
      onSaved?.()
    } catch (e) {
      setSaveError(e instanceof Error ? e.message : 'Erro ao adicionar consultor')
    } finally {
      setConsultorBusy(false)
    }
  }

  async function handleRemoveConsultor(id: string) {
    if (!session) return
    setConsultorBusy(true)
    setSaveError('')
    try {
      const additionals = currentAdditionalIds().filter((cid) => cid !== id)
      await clientApi.patch(`/training-sessions/${sessionId}`, { additionalConsultantsIds: additionals })
      await fetchData()
      onSaved?.()
    } catch (e) {
      setSaveError(e instanceof Error ? e.message : 'Erro ao remover consultor')
    } finally {
      setConsultorBusy(false)
    }
  }

  // ── Participantes ─────────────────────────────────────────────────────────────

  function setParticipantField(field: keyof ParticipantForm, value: string) {
    setParticipantForm((p) => ({ ...p, [field]: value }))
  }

  async function handleAddParticipant() {
    if (!participantForm.name.trim() || !participantForm.cpf.trim()) return
    setParticipantBusy(true)
    setParticipantError('')
    try {
      await clientApi.post(`/training-sessions/${sessionId}/participants`, {
        name: participantForm.name.trim(),
        cpf: participantForm.cpf.replace(/\D/g, ''),
        email: participantForm.email.trim() || undefined,
        cnhCategory: participantForm.cnhCategory || undefined,
        cnhExpiration: participantForm.cnhExpiration || undefined,
      })
      setParticipantForm(emptyParticipantForm)
      setShowAddParticipant(false)
      await fetchData()
    } catch (e) {
      setParticipantError(e instanceof Error ? e.message : 'Erro ao adicionar participante')
    } finally {
      setParticipantBusy(false)
    }
  }

  // ── Avaliação ─────────────────────────────────────────────────────────────────

  /** Apenas atribui o participante ao consultor logado, sem abrir o checklist */
  async function handleAtribuir(p: BackendParticipant) {
    setBusy(true)
    setSaveError('')
    try {
      await clientApi.post('/practical-assessments/assign', { participantIds: [p.id] })
      await fetchData()
    } catch (e) {
      setSaveError(e instanceof Error ? e.message : 'Erro ao atribuir participante')
    } finally {
      setBusy(false)
    }
  }

  /** Abre o checklist de avaliação (participante já atribuído ao consultor logado) */
  function openAssessment(p: BackendParticipant) {
    setAssessmentParticipant(p)
    setAssessmentOpen(true)
  }

  /** Reavaliar: atribui + abre checklist */
  async function handleReavaliar(p: BackendParticipant) {
    setBusy(true)
    setSaveError('')
    try {
      await clientApi.post('/practical-assessments/assign', { participantIds: [p.id] })
      await fetchData()
    } catch (e) {
      setSaveError(e instanceof Error ? e.message : 'Erro ao atribuir participante')
      setBusy(false)
      return
    }
    setBusy(false)
    setAssessmentParticipant(p)
    setAssessmentOpen(true)
  }

  async function handleAssessmentSaved() {
    setAssessmentOpen(false)
    setAssessmentParticipant(null)
    await fetchData()
    onSaved?.()
  }

  // ── Ciclo de vida da sessão ───────────────────────────────────────────────────

  async function handleLifecycle(action: 'start' | 'complete') {
    setBusy(true)
    setSaveError('')
    try {
      await clientApi.post(`/training-sessions/${sessionId}/${action === 'start' ? 'start' : 'complete'}`, {})
      await fetchData()
      onSaved?.()
    } catch (e) {
      setSaveError(e instanceof Error ? e.message : 'Erro na operação')
    } finally {
      setBusy(false)
    }
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────────

  const participants = session?.participants ?? []
  const sessionConsultants = session?.consultants ?? []
  const additionals = sessionConsultants.filter((sc) => sc.consultant.id !== session?.responsibleConsultant?.id)

  const availableToAdd = allConsultants.filter(
    (c) => !sessionConsultants.some((sc) => sc.consultant.id === c.id)
  )

  // Responsabilidade de iniciar/concluir a sessão: ADMIN ou o consultor responsável por ela
  // (consultores adicionais/colaboradores só avaliam participantes, não controlam o ciclo de vida da sessão)
  const isResponsibleConsultant = !!consultantId && session?.responsibleConsultant?.id === consultantId
  const canManageLifecycle = isAdmin || isResponsibleConsultant

  const canEdit = isAdmin && (session?.status === 'PLANEJADO' || session?.status === 'EM_ANDAMENTO')
  const canStart = canManageLifecycle && session?.status === 'PLANEJADO'
  const canComplete = canManageLifecycle && session?.status === 'EM_ANDAMENTO' && participants.length > 0 &&
    participants.every((p) => p.participationType === 'SOMENTE_TEORICA' || p.status === 'APROVADO' || p.status === 'NECESSITA_REAVALIACAO')

  function courseTypeLabel(): string {
    if (!session) return '—'
    const { theoryHours, practiceHours } = session.course
    return `${theoryHours}h teórica${practiceHours > 0 ? ` + ${practiceHours}h prática` : ''}`
  }

  const drawerTitle = session
    ? `${session.company.name} — ${session.course.name}`
    : 'Gerenciar Sessão'

  // ── Footer ────────────────────────────────────────────────────────────────────

  const footer = session ? (
    <div className={styles.footerRow}>
      <div className={styles.footerLeft}>
        {saveError && <span className={styles.saveError}>{saveError}</span>}
      </div>
      <div className={styles.footerRight}>
        {canStart && (
          <button className={`${styles.footerBtn} ${styles.footerBtnPrimary}`} onClick={() => handleLifecycle('start')} disabled={busy}>
            Iniciar Treinamento
          </button>
        )}
        {canComplete && (
          <button className={`${styles.footerBtn} ${styles.footerBtnSuccess}`} onClick={() => handleLifecycle('complete')} disabled={busy}>
            Concluir Treinamento
          </button>
        )}
        {canEdit && dirty && (
          <button className={`${styles.footerBtn} ${styles.footerBtnSave}`} onClick={handleSave} disabled={busy}>
            {busy ? <Loader2 size={14} className={styles.spin} /> : null}
            Salvar Alterações
          </button>
        )}
      </div>
    </div>
  ) : null

  // ── Render ────────────────────────────────────────────────────────────────────

  return (
    <>
      <Drawer open={open} title={drawerTitle} onClose={onClose} footer={footer} maxWidth="76rem">
        {loading ? (
          <div className={styles.loadingState}>
            <Loader2 size={24} className={styles.spin} />
          </div>
        ) : !session ? (
          <p className={styles.errorText}>{saveError || 'Sessão não encontrada'}</p>
        ) : (
          <div className={styles.twoPanel}>
            {/* ── Coluna esquerda ── */}
            <div className={styles.leftCol}>

              {/* Campos somente leitura */}
              <div className={styles.section}>
                <div className={styles.fieldGrid}>
                  <div className={styles.field}>
                    <label className={styles.fieldLabel}>Treinamento</label>
                    <div className={styles.fieldReadonly}>{session.course.name}</div>
                  </div>
                  <div className={styles.field}>
                    <label className={styles.fieldLabel}>Empresa</label>
                    <div className={styles.fieldReadonly}>{session.company.name}</div>
                  </div>
                  <div className={styles.field}>
                    <label className={styles.fieldLabel}>Tipo</label>
                    <div className={styles.fieldReadonly}>{courseTypeLabel()}</div>
                  </div>
                  <div className={styles.field}>
                    <label className={styles.fieldLabel}>Consultor Responsável</label>
                    <div className={styles.fieldReadonly}>{session.responsibleConsultant?.name ?? 'Consultor removido'}</div>
                  </div>
                </div>
              </div>

              {/* Campos editáveis */}
              <div className={styles.section}>
                <div className={styles.fieldGrid}>
                  <div className={styles.field}>
                    <label className={styles.fieldLabel}>Data</label>
                    {canEdit ? (
                      <input
                        type="date"
                        className={styles.fieldInput}
                        value={date}
                        onChange={(e) => { setDate(e.target.value); setDirty(true) }}
                      />
                    ) : (
                      <div className={styles.fieldReadonly}>
                        {date ? date.split('-').reverse().join('/') : '—'}
                      </div>
                    )}
                  </div>
                  <div className={styles.field}>
                    <label className={styles.fieldLabel}>Cidade</label>
                    {canEdit ? (
                      <input
                        type="text"
                        className={styles.fieldInput}
                        value={city}
                        onChange={(e) => { setCity(e.target.value); setDirty(true) }}
                      />
                    ) : (
                      <div className={styles.fieldReadonly}>{city || '—'}</div>
                    )}
                  </div>
                  <div className={styles.field}>
                    <label className={styles.fieldLabel}>Estado (UF)</label>
                    {canEdit ? (
                      <input
                        type="text"
                        className={styles.fieldInput}
                        value={stateField}
                        maxLength={2}
                        onChange={(e) => { setStateField(e.target.value.toUpperCase()); setDirty(true) }}
                      />
                    ) : (
                      <div className={styles.fieldReadonly}>{stateField || '—'}</div>
                    )}
                  </div>
                </div>
                <div className={styles.field} style={{ marginTop: '0.75rem' }}>
                  <label className={styles.fieldLabel}>Observações</label>
                  {canEdit ? (
                    <textarea
                      className={styles.fieldTextarea}
                      value={notes}
                      rows={3}
                      onChange={(e) => { setNotes(e.target.value); setDirty(true) }}
                    />
                  ) : (
                    <div className={`${styles.fieldReadonly} ${styles.fieldReadonlyMultiline}`}>
                      {notes || '—'}
                    </div>
                  )}
                </div>
              </div>

              {/* Colaboradores */}
              <div className={styles.section}>
                <div className={styles.sectionHeader}>
                  <span className={styles.sectionTitle}>Colaboradores</span>
                </div>

                {/* Lista de colaboradores atuais */}
                <div className={styles.collaboratorList}>
                  {additionals.length === 0 ? (
                    <p className={styles.collaboratorEmpty}>Nenhum colaborador adicionado</p>
                  ) : (
                    additionals.map((sc) => (
                      <div key={sc.consultant.id} className={styles.collaboratorItem}>
                        <span className={styles.collaboratorName}>{sc.consultant.name}</span>
                        {isAdmin && session.status !== 'CONCLUIDO' && session.status !== 'CANCELADO' && (
                          <button
                            className={styles.collaboratorRemove}
                            onClick={() => handleRemoveConsultor(sc.consultant.id)}
                            disabled={consultorBusy}
                            title="Remover colaborador"
                          >
                            <X size={13} />
                          </button>
                        )}
                      </div>
                    ))
                  )}
                </div>

                {/* Adicionar colaborador (admin) */}
                {isAdmin && session.status !== 'CONCLUIDO' && session.status !== 'CANCELADO' && (
                  <div className={styles.collaboratorAdd}>
                    <select
                      className={styles.collaboratorSelect}
                      value={consultorToAdd}
                      onChange={(e) => setConsultorToAdd(e.target.value)}
                      disabled={consultorBusy}
                    >
                      <option value="">Selecionar consultor...</option>
                      {availableToAdd.map((c) => (
                        <option key={c.id} value={c.id}>{c.name}</option>
                      ))}
                    </select>
                    <button
                      className={styles.collaboratorAddBtn}
                      onClick={handleAddConsultor}
                      disabled={!consultorToAdd || consultorBusy}
                    >
                      {consultorBusy ? <Loader2 size={13} className={styles.spin} /> : <Plus size={13} />}
                    </button>
                  </div>
                )}
              </div>

            </div>

            {/* ── Coluna direita (participantes) ── */}
            <div className={styles.rightCol}>
              <div className={styles.participantsHeader}>
                <span className={styles.sectionTitle}>
                  Participantes
                  <span className={styles.participantCount}>{participants.length}</span>
                </span>
                {(canEdit || session.status === 'EM_ANDAMENTO') && (
                  <button
                    className={styles.addParticipantBtn}
                    onClick={() => setShowAddParticipant((v) => !v)}
                  >
                    <UserPlus size={14} />
                    Adicionar
                  </button>
                )}
              </div>

              {/* Formulário de adicionar participante */}
              {showAddParticipant && (
                <div className={styles.addParticipantForm}>
                  <div className={styles.addParticipantGrid}>
                    <div className={styles.field}>
                      <label className={styles.fieldLabel}>Nome *</label>
                      <input className={styles.fieldInput} value={participantForm.name} onChange={(e) => setParticipantField('name', e.target.value)} />
                    </div>
                    <div className={styles.field}>
                      <label className={styles.fieldLabel}>CPF *</label>
                      <input className={styles.fieldInput} value={participantForm.cpf} onChange={(e) => setParticipantField('cpf', e.target.value)} placeholder="00000000000" />
                    </div>
                    <div className={styles.field}>
                      <label className={styles.fieldLabel}>E-mail</label>
                      <input className={styles.fieldInput} type="email" value={participantForm.email} onChange={(e) => setParticipantField('email', e.target.value)} />
                    </div>
                    <div className={styles.field}>
                      <label className={styles.fieldLabel}>Cat. CNH</label>
                      <input className={styles.fieldInput} value={participantForm.cnhCategory} onChange={(e) => setParticipantField('cnhCategory', e.target.value)} placeholder="B" />
                    </div>
                  </div>
                  {participantError && <p className={styles.participantError}>{participantError}</p>}
                  <div className={styles.addParticipantActions}>
                    <button className={styles.cancelSmallBtn} onClick={() => { setShowAddParticipant(false); setParticipantForm(emptyParticipantForm) }}>
                      Cancelar
                    </button>
                    <button
                      className={styles.confirmSmallBtn}
                      disabled={!participantForm.name.trim() || !participantForm.cpf.trim() || participantBusy}
                      onClick={handleAddParticipant}
                    >
                      <Check size={13} /> Confirmar
                    </button>
                  </div>
                </div>
              )}

              {/* Lista de participantes */}
              {participants.length === 0 ? (
                <p className={styles.participantEmpty}>Nenhum participante inscrito.</p>
              ) : (
                <div className={styles.participantList}>
                  {participants.map((p) => {
                    const action = getAction(p, consultantId, session.status, isAdmin)
                    return (
                      <div key={p.id} className={styles.participantRow}>
                        <div className={styles.participantInfo}>
                          <span className={styles.participantName}>{p.participant.name}</span>
                          <span className={styles.participantCpf}>{formatCpf(p.participant.cpf)}</span>
                        </div>
                        <div className={styles.participantRight}>
                          <span className={`${styles.statusBadge} ${statusCssMap[p.status] ?? ''}`}>
                            {statusLabels[p.status] ?? p.status}
                          </span>
                          {p.status === 'APROVADO' && p.assessment?.score != null && (
                            <span className={styles.scoreHint}>{Math.round(p.assessment.score)} pts</span>
                          )}
                          {/* Atribuir: reserva o participante para o consultor logado */}
                          {action === 'atribuir' && (
                            <button
                              className={`${styles.actionBtn} ${styles.actionBtnAtribuir}`}
                              onClick={() => handleAtribuir(p)}
                              disabled={busy}
                              title="Reservar para avaliação"
                            >
                              Atribuir
                            </button>
                          )}
                          {/* Avaliar: participante já atribuído — abre o checklist */}
                          {action === 'avaliar' && (
                            <button
                              className={`${styles.actionBtn} ${styles.actionBtnPrimary}`}
                              onClick={() => openAssessment(p)}
                              disabled={busy}
                            >
                              Avaliar
                            </button>
                          )}
                          {/* Reavaliar: atribui + abre checklist para nova avaliação */}
                          {action === 'reavaliar' && (
                            <button
                              className={`${styles.actionBtn} ${styles.actionBtnReavaliar}`}
                              onClick={() => handleReavaliar(p)}
                              disabled={busy}
                            >
                              Reavaliar
                            </button>
                          )}
                          {action === 'blocked' && (
                            <span className={styles.blockedLabel} title={`Com ${p.assignedConsultant?.name ?? 'outro consultor'}`}>
                              {p.assignedConsultant?.name ?? 'Outro consultor'}
                            </span>
                          )}
                        </div>
                      </div>
                    )
                  })}
                </div>
              )}
            </div>
          </div>
        )}
      </Drawer>

      {/* Assessment drawer (abre em cima do management drawer) */}
      {assessmentParticipant && (
        <AssessmentDrawer
          open={assessmentOpen}
          participantName={assessmentParticipant.participant.name}
          trainingParticipantId={assessmentParticipant.id}
          onClose={() => { setAssessmentOpen(false); setAssessmentParticipant(null) }}
          onSaved={handleAssessmentSaved}
        />
      )}
    </>
  )
}
