'use client'

import { useState, useRef } from 'react'
import Image from 'next/image'
import { Button } from '@/components/ui/button/button'
import type { CompanyFormData } from './company-edit-form'
import styles from './company-edit-form.module.css'

interface CompanyAddFormProps {
  onSave: (data: CompanyFormData, logoFile?: File) => void
  onCancel: () => void
}

function applyCnpjMask(value: string): string {
  const d = value.replace(/\D/g, '').slice(0, 14)
  if (d.length <= 2) return d
  if (d.length <= 5) return `${d.slice(0, 2)}.${d.slice(2)}`
  if (d.length <= 8) return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5)}`
  if (d.length <= 12) return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8)}`
  return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8, 12)}-${d.slice(12)}`
}

const empty: CompanyFormData = {
  name: '',
  cnpj: '',
  address: '',
  contactName: '',
  contactEmail: '',
}

export function CompanyAddForm({ onSave, onCancel }: CompanyAddFormProps) {
  const [form, setForm] = useState<CompanyFormData>(empty)
  const [logoFile, setLogoFile] = useState<File | null>(null)
  const [previewUrl, setPreviewUrl] = useState<string | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  function handleChange(field: keyof CompanyFormData, value: string) {
    const formatted = field === 'cnpj' ? applyCnpjMask(value) : value
    setForm((prev) => ({ ...prev, [field]: formatted }))
  }

  function handleLogoSelect(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setLogoFile(file)
    setPreviewUrl(URL.createObjectURL(file))
  }

  return (
    <div className={styles.wrapper}>
      <div className={styles.form}>

        <div className={styles.topRow}>
          <div
            className={styles.logoWrapper}
            style={{ position: 'relative', cursor: 'pointer' }}
            onClick={() => fileInputRef.current?.click()}
          >
            {previewUrl ? (
              <Image
                src={previewUrl}
                alt="Logo preview"
                fill
                unoptimized
                style={{ objectFit: 'contain' }}
              />
            ) : (
              <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                Adicionar logo
              </span>
            )}
            <span className={styles.logoHint}>Trocar imagem</span>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/png,image/jpeg,image/svg+xml"
              style={{ display: 'none' }}
              onChange={handleLogoSelect}
            />
          </div>
          <div className={styles.topFields}>
            <div className={styles.field}>
              <label className={styles.label}>Nome</label>
              <input className={styles.input} value={form.name} onChange={(e) => handleChange('name', e.target.value)} placeholder="Nome da empresa" />
            </div>
            <div className={styles.field}>
              <label className={styles.label}>CNPJ</label>
              <input className={styles.input} value={form.cnpj} inputMode="numeric" onChange={(e) => handleChange('cnpj', e.target.value)} placeholder="00.000.000/0000-00" />
            </div>
          </div>
        </div>

        <div className={styles.field}>
          <label className={styles.label}>Endereço</label>
          <input className={styles.input} value={form.address} onChange={(e) => handleChange('address', e.target.value)} />
        </div>

        <fieldset className={styles.fieldset}>
          <legend className={styles.legend}>Informações de contato:</legend>
          <div className={styles.field}>
            <label className={styles.label}>Nome do responsável</label>
            <input className={styles.input} value={form.contactName} onChange={(e) => handleChange('contactName', e.target.value)} />
          </div>
          <div className={styles.field}>
            <label className={styles.label}>Email do responsável</label>
            <input className={styles.input} type="email" value={form.contactEmail} onChange={(e) => handleChange('contactEmail', e.target.value)} />
          </div>
        </fieldset>

      </div>

      <div className={styles.actions}>
        <div />
        <div className={styles.actionsRight}>
          <Button variant="secondary" size="sm" onClick={onCancel}>Cancelar</Button>
          <Button variant="primary" size="sm" onClick={() => onSave(form, logoFile ?? undefined)}>Salvar</Button>
        </div>
      </div>
    </div>
  )
}
