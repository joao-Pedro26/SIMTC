'use client'

import { useState, useEffect } from 'react'
import { Plus, Loader2 } from 'lucide-react'
import { InputSearch } from '@/components/ui/input-search/input-search'
import { Button } from '@/components/ui/button/button'
import { CourseTable, type Course } from '@/features/courses/course-table'
import { Drawer } from '@/components/ui/drawer/drawer'
import { CourseEditForm, type CourseFormData } from '@/features/courses/course-edit-form'
import { CourseAddForm } from '@/features/courses/course-add-form'
import { clientApi } from '@/lib/client-api'
import { useToast } from '@/components/ui/toast/toast-provider'
import { useConfirm } from '@/components/ui/confirm-dialog/confirm-dialog-provider'
import { PageTitle } from '@/components/header/page-title'
import { useCurrentUser } from '@/components/current-user-context'
import styles from './page.module.css'

// Tipo retornado pelo backend
interface BackendCourse {
  id: string
  name: string
  vehicleType: 'LEVE' | 'PESADO' | 'MOTO'
  theoryHours: number
  practiceHours: number
  description: string
  contentItems?: any[]
}

function mapCourse(c: BackendCourse): Course & { vehicleType: string } {
  return {
    id: c.id,
    name: c.name,
    vehicleType: c.vehicleType,
    theoreticalHours: c.theoryHours,
    practicalHours: c.practiceHours,
    description: c.description,
    contentItems: c.contentItems,
  }
}

type DrawerMode = 'edit' | 'add' | null

export default function CursosPage() {
  const toast = useToast()
  const confirm = useConfirm()
  const { isConsultant } = useCurrentUser()
  const [courses, setCourses] = useState<ReturnType<typeof mapCourse>[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [query, setQuery] = useState('')
  const [selected, setSelected] = useState<ReturnType<typeof mapCourse> | null>(null)
  const [drawerMode, setDrawerMode] = useState<DrawerMode>(null)

  async function fetchCourses() {
    try {
      setLoading(true)
      const data = await clientApi.get<BackendCourse[]>('/courses')
      setCourses(data.map(mapCourse))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erro ao carregar cursos')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchCourses() }, [])

  function openEdit(c: Course) { setSelected(courses.find(x => x.id === c.id) ?? null); setDrawerMode('edit') }
  function openAdd() { setSelected(null); setDrawerMode('add') }
  function closeDrawer() { setDrawerMode(null); setSelected(null) }

  async function handleSave(data: CourseFormData) {
    if (!selected) return
    try {
      await clientApi.patch(`/courses/${selected.id}`, {
        name: data.name,
        vehicleType: data.vehicleType,
        theoryHours: Number(data.theoreticalHours),
        practiceHours: Number(data.practicalHours),
        description: data.description,
        contentItems: data.contentItems.length > 0 ? data.contentItems : null,
      })
      await fetchCourses()
      closeDrawer()
      toast.success('Curso atualizado com sucesso.')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao salvar curso.')
    }
  }

  async function handleAdd(data: CourseFormData) {
    try {
      await clientApi.post('/courses', {
        name: data.name,
        vehicleType: data.vehicleType,
        theoryHours: Number(data.theoreticalHours),
        practiceHours: Number(data.practicalHours),
        description: data.description,
        contentItems: data.contentItems.length > 0 ? data.contentItems : null,
      })
      await fetchCourses()
      closeDrawer()
      toast.success('Curso adicionado com sucesso.')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao adicionar curso.')
    }
  }

  async function handleDelete(id: string) {
    const ok = await confirm({
      title: 'Excluir curso',
      message: 'Esta ação é permanente e não pode ser desfeita. Deseja continuar?',
      confirmLabel: 'Excluir',
      variant: 'danger',
    })
    if (!ok) return
    try {
      await clientApi.delete(`/courses/${id}`)
      await fetchCourses()
      closeDrawer()
      toast.success('Curso excluído.')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao excluir curso.')
    }
  }

  return (
    <div className={styles.page}>
      <PageTitle title="Cursos" />

      <div className={styles.searchPanel}>
        <div style={{ flex: 1 }}>
          <InputSearch value={query} onChange={setQuery} placeholder="Buscar curso..." />
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
            <CourseTable
              courses={courses.filter((c) =>
                c.name.toLowerCase().includes(query.toLowerCase())
              )}
              onEdit={openEdit}
              onDelete={(c) => handleDelete(c.id)}
              readOnly={isConsultant}
            />
          </div>
        )}
      </div>

      <Drawer
        open={drawerMode !== null}
        title={
          drawerMode === 'edit' && selected
            ? isConsultant ? `Curso - ${selected.name}` : `Editar Curso - ${selected.name}`
            : 'Adicionar Curso'
        }
        onClose={closeDrawer}
      >
        {drawerMode === 'edit' && selected && (
          <CourseEditForm
            course={selected}
            onSave={handleSave}
            onDelete={() => handleDelete(selected.id)}
            onCancel={closeDrawer}
            readOnly={isConsultant}
          />
        )}
        {drawerMode === 'add' && !isConsultant && (
          <CourseAddForm
            onSave={handleAdd}
            onCancel={closeDrawer}
          />
        )}
      </Drawer>

    </div>
  )
}
