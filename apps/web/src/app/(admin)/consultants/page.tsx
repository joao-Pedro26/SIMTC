'use client'

import { useState, useEffect } from 'react'
import { Plus, Loader2 } from 'lucide-react'
import { InputSearch } from '@/components/ui/input-search/input-search'
import { Button } from '@/components/ui/button/button'
import { Drawer } from '@/components/ui/drawer/drawer'
import { ConsultantTable, type Consultant } from '@/features/consultants/consultant-table'
import { ConsultantEditForm, type ConsultantFormData } from '@/features/consultants/consultant-edit-form'
import { ConsultantAddForm } from '@/features/consultants/consultant-add-form'
import { clientApi } from '@/lib/client-api'
import { useToast } from '@/components/ui/toast/toast-provider'
import { useConfirm } from '@/components/ui/confirm-dialog/confirm-dialog-provider'
import { PageTitle } from '@/components/header/page-title'
import styles from './page.module.css'

// Tipo retornado pelo backend
interface BackendConsultant {
  id: string
  name: string
  email: string
  phone?: string | null
  signatureUrl?: string | null
  credentialDetran?: string | null
  regMte?: string | null
  active: boolean
}

function mapConsultant(c: BackendConsultant): Consultant {
  return {
    id: c.id,
    name: c.name,
    phone: c.phone ?? '',
    email: c.email,
    address: '',
    status: c.active ? 'ativo' : 'inativo',
    detranCredential: c.credentialDetran ?? '0',
    signatureUrl: c.signatureUrl ?? undefined,
  }
}

type DrawerMode = 'edit' | 'add' | null

export default function ConsultoresPage() {
  const toast = useToast()
  const confirm = useConfirm()
  const [consultants, setConsultants] = useState<Consultant[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [query, setQuery] = useState('')
  const [selected, setSelected] = useState<Consultant | null>(null)
  const [drawerMode, setDrawerMode] = useState<DrawerMode>(null)

  async function fetchConsultants() {
    try {
      setLoading(true)
      const data = await clientApi.get<BackendConsultant[]>('/consultants')
      setConsultants(data.map(mapConsultant))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erro ao carregar consultores')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchConsultants() }, [])

  function openEdit(c: Consultant) { setSelected(c); setDrawerMode('edit') }
  function openAdd() { setSelected(null); setDrawerMode('add') }
  function closeDrawer() { setDrawerMode(null); setSelected(null) }

  async function handleSave(data: ConsultantFormData) {
    if (!selected) return
    try {
      await clientApi.patch(`/consultants/${selected.id}`, {
        name: data.name,
        phone: data.phone || undefined,
        credentialDetran: data.detranCredential || undefined,
        active: data.status === 'ativo',
      })
      await fetchConsultants()
      closeDrawer()
      toast.success('Consultor atualizado com sucesso.')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao salvar consultor.')
    }
  }

  async function handleAdd(data: ConsultantFormData, signatureFile?: File) {
    try {
      // O e-mail informado é usado tanto para contato quanto para login.
      // A senha é gerada automaticamente pelo backend e enviada por e-mail ao consultor.
      const created = await clientApi.post<{ id: string }>('/consultants', {
        name: data.name,
        email: data.email,
        phone: data.phone || undefined,
      })

      // Upload da assinatura, se selecionada
      if (signatureFile && created.id) {
        const fd = new FormData()
        fd.append('file', signatureFile)
        await clientApi.upload(`/consultants/${created.id}/signature`, fd)
      }

      await fetchConsultants()
      closeDrawer()
      toast.success('Consultor adicionado com sucesso. Um e-mail com a senha de acesso foi enviado.')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao adicionar consultor.')
    }
  }

  async function handleResetPassword(id: string) {
    const ok = await confirm({
      title: 'Gerar nova senha',
      message: 'Uma nova senha será gerada e enviada por e-mail para o consultor. A senha atual deixará de funcionar. Deseja continuar?',
      confirmLabel: 'Gerar e enviar',
    })
    if (!ok) return
    try {
      await clientApi.post(`/consultants/${id}/reset-password`, {})
      toast.success('Nova senha gerada e enviada por e-mail.')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao gerar nova senha.')
    }
  }

  async function handleDelete(id: string) {
    const ok = await confirm({
      title: 'Excluir consultor',
      message: 'O consultor será excluído definitivamente e perderá o acesso ao sistema. Treinamentos, avaliações e demandas vinculados a ele NÃO são apagados — apenas ficam sem o nome do consultor (referência em branco). Deseja continuar?',
      confirmLabel: 'Excluir',
      variant: 'danger',
    })
    if (!ok) return
    try {
      await clientApi.delete<{ mode: 'deleted' }>(`/consultants/${id}`)
      await fetchConsultants()
      closeDrawer()
      toast.success('Consultor excluído.')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao excluir consultor.')
    }
  }

  return (
    <div className={styles.page}>
      <PageTitle title="Consultores" />

      <div className={styles.searchPanel}>
        <div style={{ flex: 1 }}>
          <InputSearch value={query} onChange={setQuery} placeholder="Buscar consultor..." />
        </div>
        <Button size="md" variant="primary" onClick={openAdd}>
          <Plus size={16} /> Adicionar
        </Button>
      </div>

      <div className={styles.tablePanel}>
        {loading && (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '4rem' }}>
            <Loader2 size={32} className="animate-spin" style={{ opacity: 0.3 }} />
          </div>
        )}
        {error && <p style={{ color: 'var(--error)', padding: '1.5rem' }}>{error}</p>}

        {!loading && !error && (
          <div className={styles.tableWrapper}>
            <ConsultantTable
              consultants={consultants.filter((c) =>
                c.name.toLowerCase().includes(query.toLowerCase())
              )}
              onEdit={openEdit}
              onDelete={(c) => handleDelete(c.id)}
            />
          </div>
        )}
      </div>

      <Drawer
        open={drawerMode !== null}
        title={drawerMode === 'edit' && selected ? `Editar Consultor - ${selected.name}` : 'Adicionar Consultor'}
        onClose={closeDrawer}
      >
        {drawerMode === 'edit' && selected && (
          <ConsultantEditForm
            consultantId={selected.id}
            consultant={selected}
            onSave={handleSave}
            onDelete={() => handleDelete(selected.id)}
            onCancel={closeDrawer}
            onResetPassword={() => handleResetPassword(selected.id)}
          />
        )}
        {drawerMode === 'add' && (
          <ConsultantAddForm
            onSave={(data, signatureFile) => handleAdd(data, signatureFile)}
            onCancel={closeDrawer}
          />
        )}
      </Drawer>

    </div>
  )
}
