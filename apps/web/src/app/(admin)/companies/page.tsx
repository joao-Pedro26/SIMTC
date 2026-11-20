'use client'

import { useState, useEffect } from 'react'
import { Plus, Loader2 } from 'lucide-react'
import { InputSearch } from '@/components/ui/input-search/input-search'
import { Button } from '@/components/ui/button/button'
import { CompanyCard } from '@/features/companies/company-card'
import { Drawer } from '@/components/ui/drawer/drawer'
import { CompanyEditForm, type CompanyFormData } from '@/features/companies/company-edit-form'
import { CompanyAddForm } from '@/features/companies/company-add-form'
import { clientApi } from '@/lib/client-api'
import { useToast } from '@/components/ui/toast/toast-provider'
import { useConfirm } from '@/components/ui/confirm-dialog/confirm-dialog-provider'
import { PageTitle } from '@/components/header/page-title'
import { useCurrentUser } from '@/components/current-user-context'
import styles from './page.module.css'

// Tipo retornado pelo backend
interface BackendContact {
  id: string
  name: string
  email: string
  phone?: string | null
}

interface BackendCompany {
  id: string
  name: string
  cnpj: string
  address?: string | null
  city?: string | null
  state?: string | null
  logoUrl?: string | null
  contacts: BackendContact[]
  trainings?: Array<{ date: string | null }>
}

// Tipo interno da UI — mapeado do backend
interface Company {
  id: string
  name: string
  address: string        // endereço completo para exibição (rua, cidade, UF)
  street: string
  city: string
  state: string
  cnpj: string
  lastTraining: string   // derivado do treinamento concluído mais recente
  contactId: string
  contactName: string
  contactEmail: string
  logoUrl?: string
}

// Empresas criadas antes do seletor de cidade ficaram com "A definir" gravado
// em endereço/cidade; trata como vazio para não aparecer na tela.
function clean(v?: string | null): string {
  const t = (v ?? '').trim()
  return t.toLowerCase() === 'a definir' ? '' : t
}

function mapCompany(c: BackendCompany): Company {
  const primary = c.contacts[0]
  const lastSessionDate = c.trainings?.[0]?.date
  const street = clean(c.address)
  const city = clean(c.city)
  // A UF só faz sentido com a cidade (o "SP" fixo antigo acompanhava o "A definir")
  const state = city ? (c.state ?? '') : ''
  return {
    id: c.id,
    name: c.name,
    cnpj: c.cnpj,
    street,
    city,
    state,
    address: [street, city, state].filter(Boolean).join(', '),
    lastTraining: lastSessionDate ? lastSessionDate.split('T')[0] : '',
    contactId: primary?.id ?? '',
    contactName: primary?.name ?? '',
    contactEmail: primary?.email ?? '',
    logoUrl: c.logoUrl ?? undefined,
  }
}

type DrawerMode = 'edit' | 'add' | null

export default function EmpresasPage() {
  const toast = useToast()
  const confirm = useConfirm()
  const { isConsultant } = useCurrentUser()
  const [companies, setCompanies] = useState<Company[]>([])
  const [contactsMap, setContactsMap] = useState<Record<string, BackendContact[]>>({})
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [query, setQuery] = useState('')
  const [selected, setSelected] = useState<Company | null>(null)
  const [drawerMode, setDrawerMode] = useState<DrawerMode>(null)

  async function fetchCompanies() {
    try {
      setLoading(true)
      const data = await clientApi.get<BackendCompany[]>('/companies')
      setCompanies(data.map(mapCompany))
      const map: Record<string, BackendContact[]> = {}
      data.forEach((c) => { map[c.id] = c.contacts })
      setContactsMap(map)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erro ao carregar empresas')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchCompanies() }, [])

  const filtered = companies.filter((c) =>
    c.name.toLowerCase().includes(query.toLowerCase())
  )

  function openEdit(c: Company) { setSelected(c); setDrawerMode('edit') }
  function openAdd() { setSelected(null); setDrawerMode('add') }
  function closeDrawer() { setDrawerMode(null); setSelected(null) }

  async function handleSave(data: CompanyFormData) {
    if (!selected) return
    // Cidade digitada sem escolher da lista fica sem UF
    if (data.city && !data.state) {
      toast.error('Escolha a cidade na lista para definir a UF.')
      return
    }
    try {
      // Atualiza dados da empresa. Sem cidade (empresa antiga), mantém a que já está gravada.
      await clientApi.patch(`/companies/${selected.id}`, {
        name: data.name,
        cnpj: data.cnpj.replace(/\D/g, ''),
        address: data.address || undefined,
        ...(data.city && { city: data.city, state: data.state }),
      })

      // Atualiza contato principal se existir e nome ou email tiver mudado
      if (
        selected.contactId &&
        (data.contactName !== selected.contactName || data.contactEmail !== selected.contactEmail)
      ) {
        await clientApi.patch(`/companies/${selected.id}/contacts/${selected.contactId}`, {
          name: data.contactName,
          ...(data.contactEmail !== selected.contactEmail && { email: data.contactEmail }),
        })
      }

      // Atualiza estado local sem refetch — preserva o logoUrl atual
      const updated: Company = {
        ...selected,
        name: data.name,
        cnpj: data.cnpj,
        street: data.address,
        city: data.city || selected.city,
        state: data.city ? data.state : selected.state,
        address: [
          data.address,
          data.city || selected.city,
          data.city ? data.state : selected.state,
        ].filter(Boolean).join(', '),
        contactName: data.contactName,
        contactEmail: data.contactEmail,
      }

      setCompanies((prev) => prev.map((c) => (c.id === selected.id ? updated : c)))
      closeDrawer()
      toast.success('Empresa atualizada com sucesso.')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao salvar empresa.')
    }
  }

  async function handleAdd(data: CompanyFormData, logoFile?: File) {
    try {
      const cnpj = data.cnpj.replace(/\D/g, '')
      if (cnpj.length !== 14) {
        toast.error('CNPJ inválido — informe 14 dígitos.')
        return
      }
      if (!data.contactName || !data.contactEmail) {
        toast.error('Informe nome e e-mail do contato.')
        return
      }

      if (!data.city || !data.state) {
        toast.error('Escolha a cidade na lista para definir a UF.')
        return
      }

      const newCompany = await clientApi.post<{ id: string }>('/companies', {
        name: data.name,
        cnpj,
        address: data.address || 'A definir',
        city: data.city,
        state: data.state,
        contacts: [
          { name: data.contactName, email: data.contactEmail },
        ],
      })

      if (logoFile) {
        const fd = new FormData()
        fd.append('file', logoFile)
        await clientApi.upload(`/companies/${newCompany.id}/logo`, fd)
      }

      await fetchCompanies()
      closeDrawer()
      toast.success('Empresa adicionada com sucesso.')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao adicionar empresa.')
    }
  }

  function handleLogoUploaded(newUrl: string) {
    setCompanies((prev) =>
      prev.map((c) => (c.id === selected?.id ? { ...c, logoUrl: newUrl } : c))
    )
    setSelected((prev) => (prev ? { ...prev, logoUrl: newUrl } : prev))
  }

  async function handleDelete(id: string) {
    const ok = await confirm({
      title: 'Excluir empresa',
      message: 'Esta ação é permanente e não pode ser desfeita. Deseja continuar?',
      confirmLabel: 'Excluir',
      variant: 'danger',
    })
    if (!ok) return
    try {
      await clientApi.delete(`/companies/${id}`)
      await fetchCompanies()
      closeDrawer()
      toast.success('Empresa excluída.')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Erro ao excluir empresa.')
    }
  }

  return (
    <div className={styles.page}>
      <PageTitle title="Empresas" />

      {/* Container da busca */}
      <div className={styles.searchPanel}>
        <div style={{ flex: 1 }}>
          <InputSearch value={query} onChange={setQuery} placeholder="Buscar empresas..." />
        </div>
        {!isConsultant && (
          <Button size="md" variant="primary" onClick={openAdd}>
            <Plus size={16} /> Adicionar
          </Button>
        )}
      </div>

      {/* Container dos cards */}
      <div className={styles.gridPanel}>
        {loading && (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '4rem' }}>
            <Loader2 size={32} style={{ opacity: 0.3 }} />
          </div>
        )}
        {error && <p style={{ color: 'var(--error)', padding: '1.5rem' }}>{error}</p>}

        {!loading && !error && (
          <div className={styles.grid}>
            {filtered.map((company) => (
              <CompanyCard
                key={company.id}
                name={company.name}
                address={company.address}
                cnpj={company.cnpj}
                lastTraining={company.lastTraining}
                logoUrl={company.logoUrl}
                onClick={() => openEdit(company)}
              />
            ))}
            {filtered.length === 0 && (
              <p className={styles.empty}>Nenhuma empresa encontrada.</p>
            )}
          </div>
        )}
      </div>

      <Drawer
        open={drawerMode !== null}
        title={
          drawerMode === 'edit' && selected
            ? isConsultant ? `Empresa - ${selected.name}` : `Editar Empresa - ${selected.name}`
            : 'Adicionar Empresa'
        }
        onClose={closeDrawer}
      >
        {drawerMode === 'edit' && selected && (
          <CompanyEditForm
            companyId={selected.id}
            name={selected.name}
            cnpj={selected.cnpj}
            address={selected.street}
            city={selected.city}
            state={selected.state}
            lastTraining={selected.lastTraining}
            contactName={selected.contactName}
            contactEmail={selected.contactEmail}
            contacts={contactsMap[selected.id] ?? []}
            logoUrl={selected.logoUrl}
            onSave={handleSave}
            onDelete={() => handleDelete(selected.id)}
            onCancel={closeDrawer}
            onLogoUploaded={handleLogoUploaded}
            readOnly={isConsultant}
          />
        )}
        {drawerMode === 'add' && !isConsultant && (
          <CompanyAddForm
            onSave={(data, logoFile) => handleAdd(data, logoFile)}
            onCancel={closeDrawer}
          />
        )}
      </Drawer>

    </div>
  )
}
