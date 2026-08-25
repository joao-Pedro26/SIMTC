'use client'

import { useState, useEffect, useCallback } from 'react'
import { Plus, Loader2 } from 'lucide-react'
import { InputSearch } from '@/components/ui/input-search/input-search'
import { Button } from '@/components/ui/button/button'
import { Drawer } from '@/components/ui/drawer/drawer'
import { TrainingSessionTable } from '@/features/training-sessions/training-session-table'
import { TrainingSessionAddForm, type TrainingSessionFormData } from '@/features/training-sessions/training-session-add-form'
import { TrainingSessionDetailTabs } from '@/features/training-sessions/training-session-detail-tabs'
import { SessionManagementDrawer } from '@/features/training-sessions/session-management-drawer'
import { clientApi } from '@/lib/client-api'
import { useToast } from '@/components/ui/toast/toast-provider'
import { useConfirm } from '@/components/ui/confirm-dialog/confirm-dialog-provider'
import { useCurrentUser } from '@/components/current-user-context'
import type { TrainingSession, TrainingCompany, TrainingCourse, TrainingConsultant } from '@/features/training-sessions/types'
import { PageTitle } from '@/components/header/page-title'
import styles from './page.module.css'

// Tipo da resposta paginada do backend
interface PaginatedResponse<T> {
  data: T[]
  total: number
  page: number
  limit: number
  totalPages: number
}

// Tipos retornados pelo backend (matches Prisma includes)
interface BackendSession {
  id: string
  company: { id: string; name: string; logoUrl?: string | null }
  course: { id: string; name: string }
  responsibleConsultant: { id: string; name: string } | null
  consultants?: Array<{ consultant: { id: string; name: string } }>
  city: string
  state: string
  date?: string | null
  participantCount?: number | null
  notes?: string | null
  status: TrainingSession['status']
  qrCodeToken: string
}

function mapSession(s: BackendSession): TrainingSession {
  return {
    id: s.id,
    company: { id: s.company.id, name: s.company.name, logoUrl: s.company.logoUrl ?? null },
    course: {
      id: s.course.id,
      name: s.course.name,
      theoryHours: 0,
      practiceHours: 0,
    },
    responsibleConsultant: s.responsibleConsultant,
    additionalConsultants: s.consultants
      ?.filter((sc) => sc.consultant.id !== s.responsibleConsultant?.id)
      .map((sc) => sc.consultant) ?? [],
    city: s.city,
    state: s.state,
    date: s.date ? s.date.split('T')[0] : '',
    participantCount: s.participantCount ?? 0,
    notes: s.notes ?? null,
    status: s.status,
    qrCodeToken: s.qrCodeToken,
    participants: [],
  }
}

type DrawerMode = 'add' | 'detail' | 'manage' | null

export default function TreinamentosPage() {
  const toast = useToast()
  const confirm = useConfirm()
  const { isConsultant } = useCurrentUser()
  const [sessions, setSessions] = useState<TrainingSession[]>([])
  const [companies, setCompanies] = useState<TrainingCompany[]>([])
  const [courses, setCourses] = useState<TrainingCourse[]>([])
  const [consultants, setConsultants] = useState<TrainingConsultant[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const [query, setQuery] = useState('')
  const [drawerMode, setDrawerMode] = useState<DrawerMode>(null)
  const [selected, setSelected] = useState<TrainingSession | null>(null)

  async function fetchAll() {
    try {
      setLoading(true)

      const [sessionsRes, companiesRes, coursesRes, consultantsRes] = await Promise.all([
        clientApi.get<PaginatedResponse<BackendSession>>('/training-sessions?limit=200'),
        clientApi.get<Array<{ id: string; name: string; logoUrl?: string | null }>>('/companies'),
        clientApi.get<Array<{ id: string; name: string; theoryHours: number; practiceHours: number }>>('/courses'),
        clientApi.get<Array<{ id: string; name: string }>>('/consultants'),
      ])

      const mappedCompanies = companiesRes.map((c) => ({ id: c.id, name: c.name, logoUrl: c.logoUrl ?? null }))
      const mappedSessions = sessionsRes.data.map(mapSession).map((s) => {
        if (s.company.logoUrl) return s
        const match = mappedCompanies.find((c) => c.id === s.company.id)
        return match ? { ...s, company: { ...s.company, logoUrl: match.logoUrl } } : s
      })
      setSessions(mappedSessions)
      setCompanies(mappedCompanies)
      setCourses(coursesRes.map((c) => ({ id: c.id, name: c.name, theoryHours: c.theoryHours, practiceHours: c.practiceHours })))
      setConsultants(consultantsRes)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erro ao carregar dados')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchAll() }, [])

  function openAdd() {
    setSelected(null)
    setDrawerMode('add')
  }

  function openDetail(session: TrainingSession) {
    setSelected(session)
    setDrawerMode('detail')
  }

  function openManage(session?: TrainingSession) {
    if (session) setSelected(session)
    setDrawerMode('manage')
  }

  function closeDrawer() {
    setDrawerMode(null)
    setSelected(null)
  }

  async function handleAdd(data: TrainingSessionFormData) {
    try {
      await clientApi.post('/training-sessions', {
        companyId: data.companyId,
        courseId: data.courseId,
        responsibleConsultantId: data.responsibleConsultantId,
        additionalConsultantsIds: data.additionalConsultantIds,
        city: data.city,
        state: data.state,
        date: data.date || undefined,
        participantCount: data.participantCount ? Number(data.participantCount) : undefined,
        notes: data.notes || undefined,
      })
      await fetchAll()
      closeDrawer()
      toast.success('Treinamento criado com sucesso.')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao criar treinamento.')
    }
  }

  async function handleDelete(id: string) {
    const session = sessions.find((s) => s.id === id)
    const label = session ? `${session.company.name} — ${session.course.name}` : 'este treinamento'
    const ok = await confirm({
      title: 'Excluir treinamento',
      message: `Tem certeza que deseja excluir "${label}"? Todos os participantes, avaliações e certificados vinculados serão removidos.`,
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
      variant: 'danger',
    })
    if (!ok) return
    try {
      await clientApi.delete(`/training-sessions/${id}`)
      setSessions((prev) => prev.filter((s) => s.id !== id))
      toast.success('Treinamento excluído.')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao excluir treinamento.')
    }
  }

  const handleSessionChanged = useCallback((updated: TrainingSession) => {
    setSessions((prev) => prev.map((s) => (s.id === updated.id ? updated : s)))
    setSelected(updated)
  }, [])

  const drawerTitle =
    drawerMode === 'add'
      ? 'Adicionar Treinamento'
      : selected
      ? `${selected.company.name} — ${selected.course.name}`
      : ''

  // Para o modo 'manage', o SessionManagementDrawer gerencia seu próprio título/conteúdo

  return (
    <div className={styles.page}>
      <PageTitle title="Treinamentos" />

      <div className={styles.searchPanel}>
        <div style={{ flex: 1 }}>
          <InputSearch value={query} onChange={setQuery} placeholder="Buscar por empresa ou cidade..." />
        </div>
        {!isConsultant && (
          <Button size="md" variant="primary" onClick={openAdd}>
            <Plus size={16} /> Adicionar
          </Button>
        )}
      </div>

      <div className={styles.tablePanel}>
        {loading && (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '4rem' }}>
            <Loader2 size={32} style={{ opacity: 0.3 }} />
          </div>
        )}
        {error && <p style={{ color: 'var(--error)', padding: '1.5rem' }}>{error}</p>}

        {!loading && !error && (
          <div className={styles.tableWrapper}>
            <TrainingSessionTable
              sessions={sessions.filter((s) =>
                s.company.name.toLowerCase().includes(query.toLowerCase()) ||
                s.city.toLowerCase().includes(query.toLowerCase())
              )}
              onSelect={openDetail}
              onDelete={isConsultant ? undefined : handleDelete}
            />
          </div>
        )}
      </div>

      {/* Drawer de detalhes / adicionar */}
      <Drawer
        open={drawerMode === 'add' || drawerMode === 'detail'}
        title={drawerTitle}
        onClose={closeDrawer}
      >
        {drawerMode === 'add' && !isConsultant && (
          <TrainingSessionAddForm
            companies={companies}
            courses={courses}
            consultants={consultants}
            onSave={handleAdd}
            onCancel={closeDrawer}
          />
        )}
        {drawerMode === 'detail' && selected && (
          <TrainingSessionDetailTabs
            sessionId={selected.id}
            onSessionChanged={handleSessionChanged}
            onManage={() => openManage()}
            readOnly={isConsultant}
          />
        )}
      </Drawer>

      {/* Drawer de gerenciamento completo — inclui a avaliação de participantes,
          por isso fica acessível também ao CONSULTANT (atribuído ou responsável);
          o próprio drawer restringe edição de dados da sessão e início/conclusão
          a ADMIN / consultor responsável internamente. */}
      {selected && (
        <SessionManagementDrawer
          open={drawerMode === 'manage'}
          sessionId={selected.id}
          onClose={closeDrawer}
          onSaved={() => { fetchAll(); }}
        />
      )}

    </div>
  )
}
