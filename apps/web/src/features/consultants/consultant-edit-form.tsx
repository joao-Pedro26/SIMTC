'use client'

import { useState, useEffect } from 'react'
import { Loader2, PenLine, KeyRound } from 'lucide-react'
import { Button } from '@/components/ui/button/button'
import { clientApi } from '@/lib/client-api'
import type { Consultant } from './consultant-table'
import styles from './consultant-edit-form.module.css'

export interface ConsultantFormData {
  name: string
  email: string
  address: string
  phone: string
  detranCredential: string
  status: 'ativo' | 'inativo'
}

interface ConsultantEditFormProps {
  consultantId: string
  consultant: Consultant
  onSave: (data: ConsultantFormData) => void
  onDelete: () => void
  onCancel: () => void
  onResetPassword: () => void
}

function applyPhoneMask(value: string): string {
  const d = value.replace(/\D/g, '').slice(0, 11)
  if (d.length === 0) return ''
  if (d.length <= 2)  return `(${d}`
  if (d.length <= 6)  return `(${d.slice(0, 2)}) ${d.slice(2)}`
  if (d.length <= 10) return `(${d.slice(0, 2)}) ${d.slice(2, 6)}-${d.slice(6)}`
  return `(${d.slice(0, 2)}) ${d.slice(2, 7)}-${d.slice(7)}`
}

export function ConsultantEditForm({ consultantId, consultant, onSave, onDelete, onCancel, onResetPassword }: ConsultantEditFormProps) {
  const [form, setForm] = useState<ConsultantFormData>({
    name: consultant.name,
    email: consultant.email,
    address: consultant.address,
    phone: applyPhoneMask(consultant.phone),
    detranCredential: consultant.detranCredential ?? '',
    status: consultant.status,
  })
  const [signatureFile, setSignatureFile] = useState<File | null>(null)
  // signatureExists: se há path salvo no banco (para label do botão)
  const [signatureExists, setSignatureExists] = useState(!!consultant.signatureUrl)
  // displayUrl: signed URL temporária para exibir a imagem
  const [displayUrl, setDisplayUrl] = useState<string | undefined>(undefined)
  const [uploading, setUploading] = useState(false)
  const [uploadError, setUploadError] = useState('')

  // Busca signed URL ao abrir o form (se já tem assinatura salva)
  useEffect(() => {
    if (!consultant.signatureUrl) return
    clientApi.get<{ signedUrl: string }>(`/consultants/${consultantId}/signature-url`)
      .then((res) => setDisplayUrl(res.signedUrl))
      .catch(() => { /* silencioso — imagem simplesmente não aparece */ })
  }, [consultantId, consultant.signatureUrl])

  function handleChange(field: keyof ConsultantFormData, value: string) {
    if (field === 'phone') value = applyPhoneMask(value)
    setForm((prev) => ({ ...prev, [field]: value }))
  }

  async function handleSignatureChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setSignatureFile(file)
    const fd = new FormData()
    fd.append('file', file)
    setUploading(true)
    setUploadError('')
    try {
      const res = await clientApi.upload<{ signedUrl: string }>(
        `/consultants/${consultantId}/signature`,
        fd
      )
      setDisplayUrl(res.signedUrl)
      setSignatureExists(true)
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : 'Erro ao fazer upload da assinatura')
    } finally {
      setUploading(false)
    }
  }

  return (
    <div className={styles.wrapper}>
      <div className={styles.form}>

        {form.status === 'inativo' && (
          <div className={styles.field} style={{ background: 'var(--surface-muted, #f5f5f5)', padding: '0.75rem', borderRadius: '0.5rem' }}>
            <p style={{ fontSize: '0.8rem', margin: 0 }}>
              Este consultor está <strong>desativado</strong>. Ele não consegue mais logar nem aparece para novas atribuições, mas o cadastro e o histórico continuam intactos. Use &ldquo;Deletar&rdquo; abaixo para removê-lo definitivamente.
            </p>
            <Button
              variant="secondary"
              size="sm"
              style={{ alignSelf: 'flex-start', marginTop: '0.5rem' }}
              onClick={() => setForm((prev) => ({ ...prev, status: 'ativo' }))}
            >
              Reativar consultor
            </Button>
          </div>
        )}

        <div className={styles.field}>
          <label className={styles.label}>Nome:</label>
          <input className={styles.input} value={form.name} onChange={(e) => handleChange('name', e.target.value)} />
        </div>

        <div className={styles.field}>
          <label className={styles.label}>E-mail:</label>
          <input
            className={styles.input}
            type="email"
            value={form.email}
            readOnly
            title="O e-mail de login não pode ser alterado por aqui"
            style={{ opacity: 0.6, cursor: 'not-allowed' }}
          />
        </div>

        <div className={styles.row2}>
          <div className={styles.field}>
            <label className={styles.label}>Telefone:</label>
            <input
              className={styles.input}
              value={form.phone}
              onChange={(e) => handleChange('phone', e.target.value)}
              inputMode="numeric"
              placeholder="(00) 00000-0000"
            />
          </div>
          <div className={styles.field}>
            <label className={styles.label}>Credencial do Detran:</label>
            <input className={styles.input} value={form.detranCredential} onChange={(e) => handleChange('detranCredential', e.target.value)} />
          </div>
        </div>

        <div className={styles.field}>
          <label className={styles.label}>Assinatura:</label>

          {/* Preview */}
          <div className={styles.signaturePreview}>
            {uploading ? (
              <div className={styles.signatureLoading}>
                <Loader2 size={22} className={styles.spinner} />
                <span>Enviando...</span>
              </div>
            ) : displayUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={displayUrl}
                alt="Assinatura"
                style={{ width: '100%', height: '100%', objectFit: 'contain', padding: '0.5rem' }}
              />
            ) : signatureExists ? (
              <div className={styles.signatureLoading}>
                <Loader2 size={18} className={styles.spinner} />
                <span>Carregando...</span>
              </div>
            ) : (
              <div className={styles.signaturePlaceholder}>
                <PenLine size={22} />
                <span>Sem assinatura cadastrada</span>
              </div>
            )}
          </div>

          {/* Upload */}
          <div className={styles.fileWrapper}>
            <label className={styles.fileLabel}>
              <span>{signatureExists ? 'Trocar imagem' : 'Inserir Imagem'}</span>
              <input
                type="file"
                accept="image/*"
                className={styles.fileInput}
                onChange={(e) => handleSignatureChange(e)}
              />
            </label>
            <span className={styles.fileName}>
              {signatureFile ? signatureFile.name : 'Nenhum arquivo escolhido'}
            </span>
          </div>

          {uploadError && (
            <p style={{ fontSize: '0.75rem', color: '#e53e3e' }}>{uploadError}</p>
          )}
        </div>

        <div className={styles.field}>
          <label className={styles.label}>Senha de acesso:</label>
          <Button variant="secondary" size="sm" onClick={onResetPassword} style={{ alignSelf: 'flex-start' }}>
            <KeyRound size={14} /> Gerar nova senha e reenviar por e-mail
          </Button>
          <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
            Gera uma nova senha aleatória e envia por e-mail para o consultor. A senha atual deixa de funcionar.
          </p>
        </div>

      </div>

      <div className={styles.actions}>
        <Button variant="danger" size="sm" onClick={onDelete}>Deletar</Button>
        <div className={styles.actionsRight}>
          <Button variant="secondary" size="sm" onClick={onCancel}>Cancelar</Button>
          <Button variant="primary" size="sm" onClick={() => onSave(form)}>Salvar</Button>
        </div>
      </div>
    </div>
  )
}
