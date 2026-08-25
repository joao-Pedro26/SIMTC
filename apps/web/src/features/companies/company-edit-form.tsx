'use client'

import { useState, useRef, useEffect } from 'react'
import Image from 'next/image'
import { Loader2, Pencil, Trash2, Plus, X, Check } from 'lucide-react'
import { Button } from '@/components/ui/button/button'
import { clientApi } from '@/lib/client-api'
import styles from './company-edit-form.module.css'

type Tab = 'info' | 'contacts' | 'trainings'

interface Training {
  id: string
  courseName: string
  date: string | null
  status: string
}

interface BackendSession {
  id: string
  course: { name: string }
  date?: string | null
  status: string
}

interface Contact {
  id: string
  name: string
  email: string
  phone?: string | null
}

function applyCnpjMask(value: string): string {
  const d = value.replace(/\D/g, '').slice(0, 14)
  if (d.length <= 2) return d
  if (d.length <= 5) return `${d.slice(0, 2)}.${d.slice(2)}`
  if (d.length <= 8) return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5)}`
  if (d.length <= 12) return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8)}`
  return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8, 12)}-${d.slice(12)}`
}

const statusLabels: Record<string, string> = {
  PLANEJADO: 'Planejado',
  EM_ANDAMENTO: 'Em Andamento',
  CONCLUIDO: 'Concluído',
  CANCELADO: 'Cancelado',
}

interface CompanyEditFormProps {
  companyId: string
  name: string
  cnpj: string
  address: string
  lastTraining: string  // derivado — read-only
  contactName: string
  contactEmail: string
  contacts?: Contact[]
  logoUrl?: string
  onSave: (data: CompanyFormData) => void
  onDelete: () => void
  onCancel: () => void
  onLogoUploaded?: (newUrl: string) => void
  /** Modo somente-leitura (ex.: CONSULTANT) — trava edição, upload de logo e ações de salvar/excluir */
  readOnly?: boolean
}

export interface CompanyFormData {
  name: string
  cnpj: string
  address: string
  contactName: string
  contactEmail: string
}

export function CompanyEditForm({
  companyId,
  name,
  cnpj,
  address,
  lastTraining,
  contactName,
  contactEmail,
  contacts: initialContacts = [],
  logoUrl,
  onSave,
  onDelete,
  onCancel,
  onLogoUploaded,
  readOnly = false,
}: CompanyEditFormProps) {
  const [tab, setTab] = useState<Tab>('info')
  const [trainings, setTrainings] = useState<Training[]>([])
  const [loadingTrainings, setLoadingTrainings] = useState(false)

  // ── Responsáveis ──────────────────────────────────────────
  const [contacts, setContacts] = useState<Contact[]>(initialContacts)
  const [editingContactId, setEditingContactId] = useState<string | null>(null)
  const [editContactForm, setEditContactForm] = useState<Omit<Contact, 'id'>>({ name: '', email: '', phone: '' })
  const [addingContact, setAddingContact] = useState(false)
  const [newContactForm, setNewContactForm] = useState<Omit<Contact, 'id'>>({ name: '', email: '', phone: '' })
  const [contactError, setContactError] = useState('')
  const [contactLoading, setContactLoading] = useState(false)

  async function handleAddContact() {
    if (!newContactForm.name || !newContactForm.email) {
      setContactError('Nome e e-mail são obrigatórios')
      return
    }
    setContactLoading(true)
    setContactError('')
    try {
      const created = await clientApi.post<Contact>(`/companies/${companyId}/contacts`, {
        name: newContactForm.name,
        email: newContactForm.email,
        phone: newContactForm.phone || undefined,
      })
      setContacts((prev) => [...prev, created])
      setAddingContact(false)
      setNewContactForm({ name: '', email: '', phone: '' })
    } catch (e) {
      setContactError(e instanceof Error ? e.message : 'Erro ao adicionar responsável')
    } finally {
      setContactLoading(false)
    }
  }

  function startEditContact(contact: Contact) {
    setEditingContactId(contact.id)
    setEditContactForm({ name: contact.name, email: contact.email, phone: contact.phone ?? '' })
    setContactError('')
  }

  async function handleSaveContact(contactId: string) {
    setContactLoading(true)
    setContactError('')
    try {
      const updated = await clientApi.patch<Contact>(
        `/companies/${companyId}/contacts/${contactId}`,
        { name: editContactForm.name, email: editContactForm.email, phone: editContactForm.phone || undefined },
      )
      setContacts((prev) => prev.map((c) => (c.id === contactId ? updated : c)))
      setEditingContactId(null)
    } catch (e) {
      setContactError(e instanceof Error ? e.message : 'Erro ao salvar responsável')
    } finally {
      setContactLoading(false)
    }
  }

  async function handleDeleteContact(contactId: string) {
    setContactLoading(true)
    setContactError('')
    try {
      await clientApi.delete(`/companies/${companyId}/contacts/${contactId}`)
      setContacts((prev) => prev.filter((c) => c.id !== contactId))
    } catch (e) {
      setContactError(e instanceof Error ? e.message : 'Erro ao remover responsável')
    } finally {
      setContactLoading(false)
    }
  }

  useEffect(() => {
    if (tab !== 'trainings') return
    setLoadingTrainings(true)
    clientApi
      .get<{ data: BackendSession[] }>(`/training-sessions?companyId=${companyId}&limit=100`)
      .then((res) =>
        setTrainings(
          res.data.map((s) => ({
            id: s.id,
            courseName: s.course.name,
            date: s.date ? s.date.split('T')[0].split('-').reverse().join('/') : null,
            status: s.status,
          })),
        ),
      )
      .catch(() => setTrainings([]))
      .finally(() => setLoadingTrainings(false))
  }, [tab, companyId])
  const [form, setForm] = useState<CompanyFormData>({
    name,
    cnpj: applyCnpjMask(cnpj),
    address,
    contactName,
    contactEmail,
  })

  const [currentLogoUrl, setCurrentLogoUrl] = useState(logoUrl)
  const [uploadTs, setUploadTs] = useState<number | null>(null)
  const [uploading, setUploading] = useState(false)
  const [uploadError, setUploadError] = useState('')
  const fileInputRef = useRef<HTMLInputElement>(null)

  // URL com cache-buster para forçar o browser a buscar a imagem nova
  // após upload (o Supabase reutiliza a mesma URL via upsert)
  const displayLogoUrl = currentLogoUrl
    ? uploadTs ? `${currentLogoUrl}?t=${uploadTs}` : currentLogoUrl
    : '/logo-simtc.png'

  function handleChange(field: keyof CompanyFormData, value: string) {
    const formatted = field === 'cnpj' ? applyCnpjMask(value) : value
    setForm((prev) => ({ ...prev, [field]: formatted }))
  }

  async function handleLogoChange(e: React.ChangeEvent<HTMLInputElement>) {
    if (readOnly) return
    const file = e.target.files?.[0]
    if (!file) return
    const fd = new FormData()
    fd.append('file', file)
    setUploading(true)
    setUploadError('')
    try {
      const res = await clientApi.upload<{ logoUrl: string }>(`/companies/${companyId}/logo`, fd)
      const ts = Date.now()
      setCurrentLogoUrl(res.logoUrl)
      setUploadTs(ts)
      onLogoUploaded?.(`${res.logoUrl}?t=${ts}`)
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : 'Erro ao fazer upload do logo')
    } finally {
      setUploading(false)
    }
  }

  return (
    <div className={styles.wrapper}>

      {/* Abas */}
      <div className={styles.tabs}>
        <button
          className={`${styles.tab} ${tab === 'info' ? styles.tabActive : ''}`}
          onClick={() => setTab('info')}
        >
          Info. Empresa
        </button>
        <button
          className={`${styles.tab} ${tab === 'contacts' ? styles.tabActive : ''}`}
          onClick={() => setTab('contacts')}
        >
          Responsáveis
        </button>
        <button
          className={`${styles.tab} ${tab === 'trainings' ? styles.tabActive : ''}`}
          onClick={() => setTab('trainings')}
        >
          Treinamentos
        </button>
      </div>

      {/* Aba: Info */}
      {tab === 'info' && (
        <div className={styles.form}>

          {/* Logo + Nome/CNPJ */}
          <div className={styles.topRow}>
            <div
              className={styles.logoWrapper}
              style={{ position: 'relative', cursor: readOnly ? 'default' : 'pointer' }}
              onClick={() => !readOnly && fileInputRef.current?.click()}
            >
              {uploading ? (
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', width: '100%', height: '100%' }}>
                  <Loader2 size={24} style={{ opacity: 0.4, animation: 'spin 1s linear infinite' }} />
                </div>
              ) : (
                <Image
                  src={displayLogoUrl}
                  alt={`Logo ${name}`}
                  fill
                  unoptimized
                  style={{ objectFit: 'contain' }}
                />
              )}
              {!readOnly && <span className={styles.logoHint}>Trocar imagem</span>}
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                style={{ display: 'none' }}
                onChange={handleLogoChange}
                disabled={readOnly}
              />
            </div>
            {uploadError && (
              <p style={{ color: '#e53e3e', fontSize: '0.8125rem' }}>{uploadError}</p>
            )}
            <div className={styles.topFields}>
              <div className={styles.field}>
                <label className={styles.label}>Nome</label>
                <input
                  className={styles.input}
                  value={form.name}
                  onChange={(e) => handleChange('name', e.target.value)}
                  readOnly={readOnly}
                />
              </div>
              <div className={styles.field}>
                <label className={styles.label}>CNPJ</label>
                <input
                  className={styles.input}
                  value={form.cnpj}
                  inputMode="numeric"
                  placeholder="00.000.000/0000-00"
                  onChange={(e) => handleChange('cnpj', e.target.value)}
                  readOnly={readOnly}
                />
              </div>
            </div>
          </div>

          {/* Endereço */}
          <div className={styles.field}>
            <label className={styles.label}>Endereço</label>
            <input
              className={styles.input}
              value={form.address}
              onChange={(e) => handleChange('address', e.target.value)}
              readOnly={readOnly}
            />
          </div>

          {/* Último Treinamento — calculado automaticamente */}
          <div className={styles.field}>
            <label className={styles.label}>Último Treinamento</label>
            <input
              className={styles.input}
              type="date"
              value={lastTraining}
              readOnly
              title="Preenchido automaticamente com a data do último treinamento concluído"
              style={{ opacity: 0.6, cursor: 'not-allowed' }}
            />
          </div>

          {/* Informações de contato */}
          <fieldset className={styles.fieldset}>
            <legend className={styles.legend}>Informações de contato:</legend>
            <div className={styles.field}>
              <label className={styles.label}>Nome do responsável</label>
              <input
                className={styles.input}
                value={form.contactName}
                onChange={(e) => handleChange('contactName', e.target.value)}
                readOnly={readOnly}
              />
            </div>
            <div className={styles.field}>
              <label className={styles.label}>Email do responsável</label>
              <input
                className={styles.input}
                type="email"
                value={form.contactEmail}
                onChange={(e) => handleChange('contactEmail', e.target.value)}
                readOnly={readOnly}
              />
            </div>
          </fieldset>
        </div>
      )}

      {/* Aba: Responsáveis */}
      {tab === 'contacts' && (
        <div className={styles.contactsList}>
          {contactError && <p className={styles.contactError}>{contactError}</p>}

          {contacts.map((contact) =>
            editingContactId === contact.id ? (
              <div key={contact.id} className={styles.contactEditRow}>
                <input
                  className={styles.input}
                  placeholder="Nome"
                  value={editContactForm.name}
                  onChange={(e) => setEditContactForm((f) => ({ ...f, name: e.target.value }))}
                />
                <input
                  className={styles.input}
                  placeholder="E-mail"
                  type="email"
                  value={editContactForm.email}
                  onChange={(e) => setEditContactForm((f) => ({ ...f, email: e.target.value }))}
                />
                <input
                  className={styles.input}
                  placeholder="Telefone (opcional)"
                  value={editContactForm.phone ?? ''}
                  onChange={(e) => setEditContactForm((f) => ({ ...f, phone: e.target.value }))}
                />
                <div className={styles.contactEditActions}>
                  <button
                    className={styles.iconBtn}
                    onClick={() => handleSaveContact(contact.id)}
                    disabled={contactLoading}
                    title="Salvar"
                  >
                    <Check size={15} />
                  </button>
                  <button
                    className={styles.iconBtn}
                    onClick={() => setEditingContactId(null)}
                    title="Cancelar"
                  >
                    <X size={15} />
                  </button>
                </div>
              </div>
            ) : (
              <div key={contact.id} className={styles.contactRow}>
                <div className={styles.contactInfo}>
                  <span className={styles.contactName}>{contact.name}</span>
                  <span className={styles.contactMeta}>{contact.email}</span>
                  {contact.phone && <span className={styles.contactMeta}>{contact.phone}</span>}
                </div>
                {!readOnly && (
                  <div className={styles.contactActions}>
                    <button
                      className={styles.iconBtn}
                      onClick={() => startEditContact(contact)}
                      title="Editar"
                    >
                      <Pencil size={14} />
                    </button>
                    <button
                      className={`${styles.iconBtn} ${styles.iconBtnDanger}`}
                      onClick={() => handleDeleteContact(contact.id)}
                      disabled={contactLoading}
                      title="Remover"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                )}
              </div>
            )
          )}

          {contacts.length === 0 && !addingContact && (
            <p className={styles.empty}>Nenhum responsável cadastrado.</p>
          )}

          {addingContact ? (
            <div className={styles.contactEditRow}>
              <input
                className={styles.input}
                placeholder="Nome *"
                value={newContactForm.name}
                onChange={(e) => setNewContactForm((f) => ({ ...f, name: e.target.value }))}
              />
              <input
                className={styles.input}
                placeholder="E-mail *"
                type="email"
                value={newContactForm.email}
                onChange={(e) => setNewContactForm((f) => ({ ...f, email: e.target.value }))}
              />
              <input
                className={styles.input}
                placeholder="Telefone (opcional)"
                value={newContactForm.phone ?? ''}
                onChange={(e) => setNewContactForm((f) => ({ ...f, phone: e.target.value }))}
              />
              <div className={styles.contactEditActions}>
                <button
                  className={styles.iconBtn}
                  onClick={handleAddContact}
                  disabled={contactLoading}
                  title="Confirmar"
                >
                  <Check size={15} />
                </button>
                <button
                  className={styles.iconBtn}
                  onClick={() => { setAddingContact(false); setNewContactForm({ name: '', email: '', phone: '' }); setContactError('') }}
                  title="Cancelar"
                >
                  <X size={15} />
                </button>
              </div>
            </div>
          ) : !readOnly ? (
            <button className={styles.addContactBtn} onClick={() => { setAddingContact(true); setContactError('') }}>
              <Plus size={14} /> Adicionar responsável
            </button>
          ) : null}
        </div>
      )}

      {/* Aba: Treinamentos */}
      {tab === 'trainings' && (
        <div className={styles.trainingsList}>
          {loadingTrainings ? (
            <div style={{ display: 'flex', justifyContent: 'center', padding: '2rem' }}>
              <Loader2 size={22} style={{ opacity: 0.4 }} />
            </div>
          ) : trainings.length === 0 ? (
            <p className={styles.empty}>Nenhum treinamento vinculado.</p>
          ) : (
            trainings.map((t) => (
              <div key={t.id} className={styles.trainingItem}>
                <span className={styles.trainingName}>{t.courseName}</span>
                <span className={styles.trainingDate}>{t.date ?? '—'}</span>
                <span className={styles.trainingDate}>{statusLabels[t.status] ?? t.status}</span>
              </div>
            ))
          )}
        </div>
      )}

      {/* Ações */}
      <div className={styles.actions}>
        {readOnly ? (
          <div className={styles.actionsRight}>
            <Button variant="secondary" size="md" onClick={onCancel}>Fechar</Button>
          </div>
        ) : (
          <>
            <Button variant="danger" size="md" onClick={onDelete}>Deletar</Button>
            <div className={styles.actionsRight}>
              <Button variant="secondary" size="md" onClick={onCancel}>Cancelar</Button>
              <Button variant="primary" size="md" onClick={() => onSave(form)}>Salvar</Button>
            </div>
          </>
        )}
      </div>

    </div>
  )
}
