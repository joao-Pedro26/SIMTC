'use client'

import { useState } from 'react'
import { Pencil, Trash2 } from 'lucide-react'
import { StatusBadge } from './status-badge'
import { ColumnFilter } from '@/components/ui/column-filter/column-filter'
import styles from './consultant-table.module.css'

function applyPhoneMask(value: string): string {
  const d = value.replace(/\D/g, '').slice(0, 11)
  if (d.length === 0) return ''
  if (d.length <= 2)  return `(${d}`
  if (d.length <= 6)  return `(${d.slice(0, 2)}) ${d.slice(2)}`
  if (d.length <= 10) return `(${d.slice(0, 2)}) ${d.slice(2, 6)}-${d.slice(6)}`
  return `(${d.slice(0, 2)}) ${d.slice(2, 7)}-${d.slice(7)}`
}

export interface Consultant {
  id: string
  name: string
  phone: string
  email: string
  address: string
  status: 'ativo' | 'inativo'
  detranCredential?: string
  signatureUrl?: string
}

interface ConsultantTableProps {
  consultants: Consultant[]
  onEdit: (consultant: Consultant) => void
  onDelete: (consultant: Consultant) => void
}

const statusOptions = [
  { label: 'Ativo',   value: 'ativo'   },
  { label: 'Inativo', value: 'inativo' },
]

export function ConsultantTable({ consultants, onEdit, onDelete }: ConsultantTableProps) {
  const [nameFilter,   setNameFilter]   = useState('')
  const [statusFilter, setStatusFilter] = useState('')

  const filtered = consultants.filter((c) => {
    const matchName   = c.name.toLowerCase().includes(nameFilter.toLowerCase())
    const matchStatus = statusFilter === '' || c.status === statusFilter
    return matchName && matchStatus
  })

  if (consultants.length === 0) {
    return <p className={styles.empty}>Nenhum consultor encontrado.</p>
  }

  return (
    <div className={styles.wrapper}>
      <table className={styles.table}>
        <thead>
          <tr className={styles.headRow}>
            <ColumnFilter
              type="text"
              label="Nome"
              value={nameFilter}
              onChange={setNameFilter}
              className={styles.th}
            />
            <th className={styles.th}>Telefone</th>
            <th className={styles.th}>E-mail</th>
            <th className={styles.th}>Endereço</th>
            <ColumnFilter
              type="select"
              label="Status"
              value={statusFilter}
              onChange={setStatusFilter}
              options={statusOptions}
              className={`${styles.th} ${styles.center}`}
            />
            <th className={styles.th} />
          </tr>
        </thead>
        <tbody>
          {filtered.length === 0 ? (
            <tr>
              <td colSpan={6} className={styles.empty}>
                Nenhum resultado com os filtros aplicados.
              </td>
            </tr>
          ) : (
            filtered.map((c) => (
              <tr key={c.id} className={styles.row}>
                <td className={styles.td}>{c.name}</td>
                <td className={styles.td}>{applyPhoneMask(c.phone)}</td>
                <td className={styles.td}>{c.email}</td>
                <td className={`${styles.td} ${styles.addressCell}`}>{c.address}</td>
                <td className={`${styles.td} ${styles.center}`}>
                  <StatusBadge status={c.status} />
                </td>
                <td className={`${styles.td} ${styles.actions}`}>
                  <button
                    className={styles.actionBtn}
                    onClick={() => onEdit(c)}
                    aria-label="Editar"
                  >
                    <Pencil size={15} />
                  </button>
                  <button
                    className={`${styles.actionBtn} ${styles.archiveBtn}`}
                    onClick={() => onDelete(c)}
                    aria-label="Excluir"
                  >
                    <Trash2 size={15} />
                  </button>
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  )
}
