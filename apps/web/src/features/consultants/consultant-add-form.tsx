'use client'

import { useState, useEffect } from 'react'
import { PenLine } from 'lucide-react'
import { Button } from '@/components/ui/button/button'
import { Select } from '@/components/ui/select/select'
import type { ConsultantFormData } from './consultant-edit-form'
import styles from './consultant-edit-form.module.css'

interface ConsultantAddFormProps {
  onSave: (data: ConsultantFormData, signatureFile?: File) => void
  onCancel: () => void
}

const empty: ConsultantFormData = {
  name: '',
  email: '',
  address: '',
  phone: '',
  detranCredential: '',
  status: 'ativo',
}

function applyPhoneMask(value: string): string {
  const d = value.replace(/\D/g, '').slice(0, 11)
  if (d.length === 0) return ''
  if (d.length <= 2)  return `(${d}`
  if (d.length <= 6)  return `(${d.slice(0, 2)}) ${d.slice(2)}`
  if (d.length <= 10) return `(${d.slice(0, 2)}) ${d.slice(2, 6)}-${d.slice(6)}`
  return `(${d.slice(0, 2)}) ${d.slice(2, 7)}-${d.slice(7)}`
}

export function ConsultantAddForm({ onSave, onCancel }: ConsultantAddFormProps) {
  const [form, setForm] = useState<ConsultantFormData>(empty)
  const [signatureFile, setSignatureFile] = useState<File | null>(null)
  const [previewUrl, setPreviewUrl] = useState<string | undefined>(undefined)

  // Cria/revoga URL de preview local ao selecionar arquivo
  useEffect(() => {
    if (!signatureFile) { setPreviewUrl(undefined); return }
    const url = URL.createObjectURL(signatureFile)
    setPreviewUrl(url)
    return () => URL.revokeObjectURL(url)
  }, [signatureFile])

  function handleChange(field: keyof ConsultantFormData, value: string) {
    if (field === 'phone') value = applyPhoneMask(value)
    setForm((prev) => ({ ...prev, [field]: value }))
  }

  return (
    <div className={styles.wrapper}>
      <div className={styles.form}>

        <div className={styles.field}>
          <label className={styles.label}>Nome:</label>
          <input className={styles.input} value={form.name} onChange={(e) => handleChange('name', e.target.value)} />
        </div>

        <div className={styles.field}>
          <label className={styles.label}>E-mail:</label>
          <input className={styles.input} type="email" value={form.email} onChange={(e) => handleChange('email', e.target.value)} />
          <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
            Este e-mail também será usado para login. Uma senha de acesso será gerada automaticamente e enviada para ele.
          </p>
        </div>

        <div className={styles.field}>
          <label className={styles.label}>Endereço:</label>
          <input className={styles.input} value={form.address} onChange={(e) => handleChange('address', e.target.value)} />
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

          {/* Preview local */}
          <div className={styles.signaturePreview}>
            {previewUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={previewUrl}
                alt="Assinatura"
                style={{ width: '100%', height: '100%', objectFit: 'contain', padding: '0.5rem' }}
              />
            ) : (
              <div className={styles.signaturePlaceholder}>
                <PenLine size={22} />
                <span>Sem assinatura cadastrada</span>
              </div>
            )}
          </div>

          <div className={styles.fileWrapper}>
            <label className={styles.fileLabel}>
              <span>{signatureFile ? 'Trocar imagem' : 'Inserir Imagem'}</span>
              <input
                type="file"
                accept="image/*"
                className={styles.fileInput}
                onChange={(e) => setSignatureFile(e.target.files?.[0] ?? null)}
              />
            </label>
            <span className={styles.fileName}>{signatureFile ? signatureFile.name : 'Nenhum arquivo escolhido'}</span>
          </div>
        </div>

        <div className={styles.field}>
          <label className={styles.label}>Status:</label>
          <Select
            value={form.status}
            onChange={(v) => handleChange('status', v)}
            options={[
              { label: 'Ativo', value: 'ativo' },
              { label: 'Inativo', value: 'inativo' },
            ]}
          />
        </div>

      </div>

      <div className={styles.actions}>
        <div />
        <div className={styles.actionsRight}>
          <Button variant="secondary" size="sm" onClick={onCancel}>Cancelar</Button>
          <Button variant="primary" size="sm" onClick={() => onSave(form, signatureFile ?? undefined)}>Salvar</Button>
        </div>
      </div>
    </div>
  )
}
