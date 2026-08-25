'use client'

import { useState, useEffect, useCallback } from 'react'
import { Plus } from 'lucide-react'
import { clientApi } from '@/lib/client-api'
import { InputSearch } from '@/components/ui/input-search/input-search'
import { Select } from '@/components/ui/select/select'
import { Button } from '@/components/ui/button/button'
import { Drawer } from '@/components/ui/drawer/drawer'
import { TopicTable } from '@/features/assessment-categories/topic-table'
import { TopicEditForm, TopicAddForm } from '@/features/assessment-categories/topic-form'
import { InfractionTable } from '@/features/assessment-categories/infraction-table'
import { InfractionEditForm, InfractionAddForm } from '@/features/assessment-categories/infraction-form'
import type { Topic } from '@/features/assessment-categories/topic-table'
import type { Infraction } from '@/features/assessment-categories/infraction-table'
import type { TopicFormData } from '@/features/assessment-categories/topic-form'
import type { InfractionFormData } from '@/features/assessment-categories/infraction-form'
import { useToast } from '@/components/ui/toast/toast-provider'
import { useConfirm } from '@/components/ui/confirm-dialog/confirm-dialog-provider'
import { PageTitle } from '@/components/header/page-title'
import { useCurrentUser } from '@/components/current-user-context'
import styles from './page.module.css'

// ── Backend shapes ──────────────────────────────────────────────────────────

interface BackendNote {
  id: string
  infractionId: string
  noteType: 'B' | 'PM' | 'M'
  comment: string
  deduction: number
}

interface BackendInfraction {
  id: string
  categoryId: string
  description: string
  order: number
  notes: BackendNote[]
}

interface BackendCategory {
  id: string
  code: string
  name: string
  description: string
  order: number
  infractions: BackendInfraction[]
}

// ── Mapping helpers ─────────────────────────────────────────────────────────

function mapCategoryToTopic(cat: BackendCategory): Topic {
  return {
    id: cat.id,
    sigla: cat.code,
    name: cat.name,
    disciplinaryText: cat.description,
  }
}

function noteByType(notes: BackendNote[], type: 'B' | 'PM' | 'M') {
  const n = notes.find((n) => n.noteType === type)
  return { comment: n?.comment ?? '', deduction: n?.deduction ?? 0 }
}

function mapInfraction(inf: BackendInfraction, cat: BackendCategory): Infraction {
  return {
    id: inf.id,
    topicId: cat.id,
    topicSigla: cat.code,
    topicName: cat.name,
    name: inf.description,
    noteB:  noteByType(inf.notes, 'B'),
    notePM: noteByType(inf.notes, 'PM'),
    noteM:  noteByType(inf.notes, 'M'),
  }
}

function mapAll(categories: BackendCategory[]): { topics: Topic[]; infractions: Infraction[] } {
  const topics: Topic[] = categories.map(mapCategoryToTopic)
  const infractions: Infraction[] = categories.flatMap((cat) =>
    cat.infractions.map((inf) => mapInfraction(inf, cat))
  )
  return { topics, infractions }
}

// ── Page ────────────────────────────────────────────────────────────────────

type InfractionDrawerMode = 'edit' | 'add' | null
type TopicDrawerMode      = 'edit' | 'add' | null

export default function TopicosEInfracoesPage() {
  const toast = useToast()
  const confirm = useConfirm()
  const { isConsultant } = useCurrentUser()
  const [topics,      setTopics]      = useState<Topic[]>([])
  const [infractions, setInfractions] = useState<Infraction[]>([])
  const [loading,     setLoading]     = useState(true)
  const [error,       setError]       = useState<string | null>(null)

  const [topicQuery,       setTopicQuery]       = useState('')
  const [infractionQuery,  setInfractionQuery]  = useState('')
  const [infractionTopic,  setInfractionTopic]  = useState('')

  const [selectedTopic,      setSelectedTopic]      = useState<Topic | null>(null)
  const [selectedInfraction, setSelectedInfraction] = useState<Infraction | null>(null)
  const [topicDrawer,        setTopicDrawer]        = useState<TopicDrawerMode>(null)
  const [infractionDrawer,   setInfractionDrawer]   = useState<InfractionDrawerMode>(null)

  // ── Fetch ──────────────────────────────────────────────────────────────

  const loadData = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const categories = await clientApi.get<BackendCategory[]>('/assessment-categories')
      const { topics, infractions } = mapAll(categories)
      setTopics(topics)
      setInfractions(infractions)
    } catch (e: any) {
      setError(e.message ?? 'Erro ao carregar dados.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { loadData() }, [loadData])

  // ── Filtered lists ─────────────────────────────────────────────────────

  const filteredTopics = topics.filter((t) =>
    t.name.toLowerCase().includes(topicQuery.toLowerCase()) ||
    t.sigla.toLowerCase().includes(topicQuery.toLowerCase())
  )

  const filteredInfractions = infractions.filter((inf) => {
    const matchQuery = inf.name.toLowerCase().includes(infractionQuery.toLowerCase()) ||
      inf.topicName.toLowerCase().includes(infractionQuery.toLowerCase())
    const matchTopic = infractionTopic === '' || inf.topicId === infractionTopic
    return matchQuery && matchTopic
  })

  const topicOptions = topics.map((t) => ({ label: `${t.sigla} — ${t.name}`, value: t.id }))

  // ── Topic handlers ─────────────────────────────────────────────────────

  function openTopicEdit(t: Topic)  { setSelectedTopic(t); setTopicDrawer('edit') }
  function openTopicAdd()           { setSelectedTopic(null); setTopicDrawer('add') }
  function closeTopicDrawer()       { setTopicDrawer(null); setSelectedTopic(null) }

  async function handleTopicSave(data: TopicFormData) {
    if (!selectedTopic) return
    try {
      await clientApi.patch(`/assessment-categories/${selectedTopic.id}`, {
        code:        data.sigla.toUpperCase(),
        name:        data.name,
        description: data.disciplinaryText,
      })
      await loadData()
      closeTopicDrawer()
      toast.success('Tópico atualizado com sucesso.')
    } catch (e: any) {
      toast.error(e.message ?? 'Erro ao salvar tópico.')
    }
  }

  async function handleTopicAdd(data: TopicFormData) {
    try {
      await clientApi.post('/assessment-categories', {
        code:        data.sigla.toUpperCase(),
        name:        data.name,
        description: data.disciplinaryText,
        order:       topics.length,
        infractions: [],
      })
      await loadData()
      closeTopicDrawer()
      toast.success('Tópico criado com sucesso.')
    } catch (e: any) {
      toast.error(e.message ?? 'Erro ao criar tópico.')
    }
  }

  async function handleTopicDelete(t: Topic) {
    const ok = await confirm({
      title: `Excluir tópico "${t.sigla}"`,
      message: `Todas as infrações vinculadas ao tópico "${t.name}" também serão excluídas. Esta ação não pode ser desfeita.`,
      confirmLabel: 'Excluir tudo',
      variant: 'danger',
    })
    if (!ok) return
    try {
      await clientApi.delete(`/assessment-categories/${t.id}`)
      // Atualiza estado imediatamente — remove tópico e todas as infrações vinculadas
      setTopics((prev) => prev.filter((topic) => topic.id !== t.id))
      setInfractions((prev) => prev.filter((inf) => inf.topicId !== t.id))
      closeTopicDrawer()
      toast.success('Tópico excluído.')
    } catch (e: any) {
      toast.error(e.message ?? 'Erro ao deletar tópico.')
    }
  }

  // ── Infraction handlers ────────────────────────────────────────────────

  function openInfractionEdit(inf: Infraction) { setSelectedInfraction(inf); setInfractionDrawer('edit') }
  function openInfractionAdd()                 { setSelectedInfraction(null); setInfractionDrawer('add') }
  function closeInfractionDrawer()             { setInfractionDrawer(null); setSelectedInfraction(null) }

  async function handleInfractionSave(data: InfractionFormData) {
    if (!selectedInfraction) return
    const categoryId = selectedInfraction.topicId
    const infractionId = selectedInfraction.id
    try {
      // Update description
      await clientApi.patch(
        `/assessment-categories/${categoryId}/infractions/${infractionId}`,
        { description: data.name }
      )
      // Update each note
      await Promise.all([
        clientApi.patch(
          `/assessment-categories/${categoryId}/infractions/${infractionId}/notes/B`,
          { comment: data.noteB.comment, deduction: data.noteB.deduction }
        ),
        clientApi.patch(
          `/assessment-categories/${categoryId}/infractions/${infractionId}/notes/PM`,
          { comment: data.notePM.comment, deduction: data.notePM.deduction }
        ),
        clientApi.patch(
          `/assessment-categories/${categoryId}/infractions/${infractionId}/notes/M`,
          { comment: data.noteM.comment, deduction: data.noteM.deduction }
        ),
      ])
      await loadData()
      closeInfractionDrawer()
      toast.success('Infração atualizada com sucesso.')
    } catch (e: any) {
      toast.error(e.message ?? 'Erro ao salvar infração.')
    }
  }

  async function handleInfractionAdd(data: InfractionFormData) {
    const categoryId = data.topicId
    if (!categoryId) { toast.warning('Selecione um tópico.'); return }
    const currentInfractions = infractions.filter((inf) => inf.topicId === categoryId)
    try {
      await clientApi.post(`/assessment-categories/${categoryId}/infractions`, {
        description: data.name,
        order:       currentInfractions.length,
        notes: [
          { noteType: 'B',  comment: data.noteB.comment,  deduction: data.noteB.deduction  },
          { noteType: 'PM', comment: data.notePM.comment, deduction: data.notePM.deduction },
          { noteType: 'M',  comment: data.noteM.comment,  deduction: data.noteM.deduction  },
        ],
      })
      await loadData()
      closeInfractionDrawer()
      toast.success('Infração criada com sucesso.')
    } catch (e: any) {
      toast.error(e.message ?? 'Erro ao criar infração.')
    }
  }

  async function handleInfractionDelete(inf: Infraction) {
    const ok = await confirm({
      title: 'Excluir infração',
      message: `A infração "${inf.name}" será excluída permanentemente.`,
      confirmLabel: 'Excluir',
      variant: 'danger',
    })
    if (!ok) return
    try {
      await clientApi.delete(`/assessment-categories/${inf.topicId}/infractions/${inf.id}`)
      // Atualiza estado imediatamente
      setInfractions((prev) => prev.filter((i) => i.id !== inf.id))
      closeInfractionDrawer()
      toast.success('Infração excluída.')
    } catch (e: any) {
      toast.error(e.message ?? 'Erro ao deletar infração.')
    }
  }

  // ── Render ─────────────────────────────────────────────────────────────

  if (loading) return <div className={styles.page}><p style={{ padding: '2rem' }}>Carregando...</p></div>
  if (error)   return <div className={styles.page}><p style={{ padding: '2rem', color: 'red' }}>{error}</p></div>

  return (
    <div className={styles.page}>
      <PageTitle title="Tópicos e Infrações" />

      <div className={styles.columns}>

        {/* ── Painel Tópicos ─────────────────────────────── */}
        <div className={styles.panel}>
          <div className={styles.panelHeader}>
            <InputSearch value={topicQuery} onChange={setTopicQuery} placeholder="Buscar" />
            {!isConsultant && (
              <Button size="sm" variant="primary" onClick={openTopicAdd}>
                <Plus size={14} /> Novo
              </Button>
            )}
          </div>
          <div className={styles.tableWrapper}>
            <TopicTable
              topics={filteredTopics}
              onEdit={openTopicEdit}
              onDelete={(t) => handleTopicDelete(t)}
              readOnly={isConsultant}
            />
          </div>
        </div>

        {/* ── Painel Infrações ───────────────────────────── */}
        <div className={styles.panel}>
          <div className={styles.panelHeader}>
            <InputSearch value={infractionQuery} onChange={setInfractionQuery} placeholder="Buscar infração..." />
            <Select value={infractionTopic} onChange={setInfractionTopic} options={topicOptions} placeholder="Filtrar por tópico" />
            {!isConsultant && (
              <Button size="sm" variant="primary" onClick={openInfractionAdd}>
                <Plus size={14} /> Novo
              </Button>
            )}
          </div>
          <div className={styles.tableWrapper}>
            <InfractionTable
              infractions={filteredInfractions}
              onEdit={openInfractionEdit}
              onDelete={(inf) => handleInfractionDelete(inf)}
              readOnly={isConsultant}
            />
          </div>
        </div>

      </div>

      {/* ── Drawer Tópico ──────────────────────────────────── */}
      <Drawer
        open={topicDrawer !== null}
        title={isConsultant ? 'Tópico' : 'Gerenciar Tópicos'}
        onClose={closeTopicDrawer}
      >
        {topicDrawer === 'edit' && selectedTopic && (
          <TopicEditForm
            topic={selectedTopic}
            onSave={handleTopicSave}
            onDelete={() => handleTopicDelete(selectedTopic)}
            onCancel={closeTopicDrawer}
            readOnly={isConsultant}
          />
        )}
        {topicDrawer === 'add' && !isConsultant && (
          <TopicAddForm
            onSave={handleTopicAdd}
            onCancel={closeTopicDrawer}
          />
        )}
      </Drawer>

      {/* ── Drawer Infração ────────────────────────────────── */}
      <Drawer
        open={infractionDrawer !== null}
        title={infractionDrawer === 'edit' ? (isConsultant ? 'Infração' : 'Editar Infração') : 'Nova Infração'}
        onClose={closeInfractionDrawer}
      >
        {infractionDrawer === 'edit' && selectedInfraction && (
          <InfractionEditForm
            infraction={selectedInfraction}
            topics={topics}
            onSave={handleInfractionSave}
            onDelete={() => handleInfractionDelete(selectedInfraction)}
            onCancel={closeInfractionDrawer}
            readOnly={isConsultant}
          />
        )}
        {infractionDrawer === 'add' && !isConsultant && (
          <InfractionAddForm
            topics={topics}
            onSave={handleInfractionAdd}
            onCancel={closeInfractionDrawer}
          />
        )}
      </Drawer>

    </div>
  )
}
