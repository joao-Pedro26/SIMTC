'use client'

import { useState, useEffect } from 'react'
import { DragDropContext, type DropResult } from '@hello-pangea/dnd'
import { Plus, Loader2 } from 'lucide-react'
import { Button } from '@/components/ui/button/button'
import { InputSearch } from '@/components/ui/input-search/input-search'
import { Drawer } from '@/components/ui/drawer/drawer'
import { KanbanColumn } from '@/features/demand-pipeline/kanban-column'
import { DemandForm, type DemandFormData } from '@/features/demand-pipeline/demand-form'
import type { Demand } from '@/features/demand-pipeline/demand-card'
import { clientApi } from '@/lib/client-api'
import { useToast } from '@/components/ui/toast/toast-provider'
import { useConfirm } from '@/components/ui/confirm-dialog/confirm-dialog-provider'
import { PageTitle } from '@/components/header/page-title'
import styles from './page.module.css'

type DemandStatus = Demand['status']
type DrawerMode = 'edit' | 'add' | null

const COLUMNS: { id: DemandStatus; title: string }[] = [
  { id: 'QUALIFICACAO', title: 'Em Qualificação' },
  { id: 'ANALISE',      title: 'Análise e Classificação' },
  { id: 'AGENDAMENTO',  title: 'Agendamento' },
]

// Tipo retornado pelo backend
interface BackendDemand {
  id: string
  companyId: string
  consultantId: string | null
  courseId: string
  status: DemandStatus
  participantCount?: number | null
  notes?: string | null
  createdAt: string
  updatedAt: string
  company: { id: string; name: string; logoUrl?: string | null }
  consultant: { id: string; name: string } | null
  course: { id: string; name: string }
}

function mapDemand(d: BackendDemand): Demand {
  return {
    id: d.id,
    companyId: d.companyId,
    companyName: d.company.name,
    companyLogoUrl: d.company.logoUrl ?? null,
    consultantId: d.consultantId ?? '',
    consultantName: d.consultant?.name ?? 'Consultor removido',
    courseId: d.courseId,
    courseType: d.course.name,
    notes: d.notes,
    participantCount: d.participantCount ?? undefined,
    status: d.status,
    createdAt: d.createdAt,
    updatedAt: d.updatedAt,
  }
}

export default function FunilDeDemandasPage() {
  const toast = useToast()
  const confirm = useConfirm()
  const [demands, setDemands] = useState<Demand[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const [companyOptions, setCompanyOptions] = useState<{ value: string; label: string }[]>([])
  const [consultantOptions, setConsultantOptions] = useState<{ value: string; label: string }[]>([])
  const [courseOptions, setCourseOptions] = useState<{ value: string; label: string }[]>([])

  const [query, setQuery] = useState('')
  const [drawerMode, setDrawerMode] = useState<DrawerMode>(null)
  const [selected, setSelected] = useState<Demand | null>(null)
  const [addStatus, setAddStatus] = useState<DemandStatus>('QUALIFICACAO')

  async function fetchAll() {
    try {
      setLoading(true)
      const [demandsRes, companiesRes, consultantsRes, coursesRes] = await Promise.all([
        clientApi.get<BackendDemand[]>('/demand-pipeline'),
        clientApi.get<Array<{ id: string; name: string }>>('/companies'),
        clientApi.get<Array<{ id: string; name: string }>>('/consultants'),
        clientApi.get<Array<{ id: string; name: string }>>('/courses'),
      ])
      setDemands(demandsRes.map(mapDemand))
      setCompanyOptions(companiesRes.map((c) => ({ value: c.id, label: c.name })))
      setConsultantOptions(consultantsRes.map((c) => ({ value: c.id, label: c.name })))
      setCourseOptions(coursesRes.map((c) => ({ value: c.id, label: c.name })))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erro ao carregar funil')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchAll() }, [])

  const filtered = demands.filter((d) =>
    d.companyName.toLowerCase().includes(query.toLowerCase()) ||
    d.courseType.toLowerCase().includes(query.toLowerCase()) ||
    d.consultantName.toLowerCase().includes(query.toLowerCase())
  )

  function demandsForColumn(colId: DemandStatus) {
    return filtered.filter((d) => d.status === colId)
  }

  function openEdit(demand: Demand) { setSelected(demand); setDrawerMode('edit') }
  function openAdd(status: DemandStatus = 'QUALIFICACAO') { setSelected(null); setAddStatus(status); setDrawerMode('add') }
  function closeDrawer() { setDrawerMode(null); setSelected(null) }

  async function handleSave(data: DemandFormData) {
    try {
      if (drawerMode === 'edit' && selected) {
        await clientApi.patch(`/demand-pipeline/${selected.id}`, {
          companyId: data.companyId,
          consultantId: data.consultantId,
          courseId: data.courseId,
          participantCount: data.participantCount ? Number(data.participantCount) : undefined,
          notes: data.notes || undefined,
        })
        // Atualiza status separadamente se mudou
        if (data.status !== selected.status) {
          await clientApi.patch(`/demand-pipeline/${selected.id}/status`, { status: data.status })
        }
        toast.success('Demanda atualizada.')
      } else {
        await clientApi.post('/demand-pipeline', {
          companyId: data.companyId,
          consultantId: data.consultantId,
          courseId: data.courseId,
          participantCount: data.participantCount ? Number(data.participantCount) : undefined,
          notes: data.notes || undefined,
        })
        toast.success('Demanda criada com sucesso.')
      }
      await fetchAll()
      closeDrawer()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao salvar demanda.')
    }
  }

  async function handleDelete() {
    if (!selected) return
    const ok = await confirm({
      title: 'Excluir demanda',
      message: 'Esta ação é permanente e não pode ser desfeita. Deseja continuar?',
      confirmLabel: 'Excluir',
      variant: 'danger',
    })
    if (!ok) return
    try {
      await clientApi.delete(`/demand-pipeline/${selected.id}`)
      await fetchAll()
      closeDrawer()
      toast.success('Demanda excluída.')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao excluir demanda.')
    }
  }

  async function onDragEnd(result: DropResult) {
    const { destination, source, draggableId } = result
    if (!destination) return
    if (destination.droppableId === source.droppableId && destination.index === source.index) return

    const newStatus = destination.droppableId as DemandStatus
    // Optimistic update
    setDemands((prev) => prev.map((d) => (d.id === draggableId ? { ...d, status: newStatus } : d)))

    try {
      await clientApi.patch(`/demand-pipeline/${draggableId}/status`, { status: newStatus })
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao mover demanda.')
      await fetchAll() // revert
    }
  }

  const drawerTitle =
    drawerMode === 'edit' && selected
      ? `Editar Demanda — ${selected.companyName}`
      : 'Nova Demanda'

  return (
    <div className={styles.page}>
      <PageTitle title="Qualificação de Demandas" />

      <div className={styles.searchPanel}>
        <div style={{ flex: 1 }}>
          <InputSearch
            value={query}
            onChange={setQuery}
            placeholder="Buscar por empresa, curso ou consultor"
          />
        </div>
        <Button size="md" variant="primary" onClick={() => openAdd()}>
          <Plus size={16} /> Adicionar
        </Button>
      </div>

      <div className={styles.boardPanel}>
        {loading && (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '4rem' }}>
            <Loader2 size={32} style={{ opacity: 0.3 }} />
          </div>
        )}
        {error && <p style={{ color: 'var(--error)', padding: '1.5rem' }}>{error}</p>}

        {!loading && !error && (
          <div className={styles.board}>
            <DragDropContext onDragEnd={onDragEnd}>
              <div className={styles.columns}>
                {COLUMNS.map((col) => (
                  <KanbanColumn
                    key={col.id}
                    id={col.id}
                    title={col.title}
                    demands={demandsForColumn(col.id)}
                    onCardClick={openEdit}
                    onAddClick={() => openAdd(col.id)}
                  />
                ))}
              </div>
            </DragDropContext>
          </div>
        )}
      </div>

      <Drawer open={drawerMode !== null} title={drawerTitle} onClose={closeDrawer}>
        {drawerMode === 'edit' && selected && (
          <DemandForm
            initial={{
              companyId: selected.companyId,
              consultantId: selected.consultantId,
              courseId: selected.courseId,
              participantCount: selected.participantCount?.toString() ?? '',
              notes: selected.notes ?? '',
              status: selected.status,
            }}
            companyOptions={companyOptions}
            consultantOptions={consultantOptions}
            courseOptions={courseOptions}
            onSave={handleSave}
            onDelete={handleDelete}
            onCancel={closeDrawer}
          />
        )}
        {drawerMode === 'add' && (
          <DemandForm
            initial={{ status: addStatus }}
            companyOptions={companyOptions}
            consultantOptions={consultantOptions}
            courseOptions={courseOptions}
            onSave={handleSave}
            onCancel={closeDrawer}
          />
        )}
      </Drawer>

    </div>
  )
}
