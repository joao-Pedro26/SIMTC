'use client'

import { useState } from 'react'
import { Settings2, Plus, Trash2 } from 'lucide-react'
import { Select } from '@/components/ui/select/select'
import formStyles from './course-edit-form.module.css'
import styles from './vehicle-type-field.module.css'

export interface VehicleTypeOption {
  id: string
  name: string
}

/** Callbacks de gerenciamento dos tipos (só o ADMIN recebe) */
export interface VehicleTypeActions {
  onCreate: (name: string) => Promise<void>
  onDelete: (type: VehicleTypeOption) => Promise<void>
}

interface VehicleTypeFieldProps {
  value: string
  onChange: (id: string) => void
  vehicleTypes: VehicleTypeOption[]
  actions?: VehicleTypeActions
}

/**
 * Select de tipo de veículo com um painel "Gerenciar" para adicionar e excluir
 * tipos sem sair do formulário do curso.
 */
export function VehicleTypeField({ value, onChange, vehicleTypes, actions }: VehicleTypeFieldProps) {
  const [managing, setManaging] = useState(false)
  const [newName, setNewName] = useState('')
  const [busy, setBusy] = useState(false)

  async function handleCreate() {
    const name = newName.trim()
    if (!name || !actions) return
    setBusy(true)
    try {
      await actions.onCreate(name)
      setNewName('')
    } finally {
      setBusy(false)
    }
  }

  async function handleDelete(t: VehicleTypeOption) {
    if (!actions) return
    setBusy(true)
    try {
      await actions.onDelete(t)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className={formStyles.field}>
      <div className={styles.labelRow}>
        <label className={formStyles.label}>Tipo de Veículo:</label>
        {actions && (
          <button
            type="button"
            className={styles.manageBtn}
            onClick={() => setManaging((m) => !m)}
          >
            <Settings2 size={13} /> {managing ? 'Fechar' : 'Gerenciar tipos'}
          </button>
        )}
      </div>

      <Select
        value={value}
        onChange={onChange}
        options={vehicleTypes.map((t) => ({ value: t.id, label: t.name }))}
      />

      {actions && managing && (
        <div className={styles.panel}>
          <ul className={styles.list}>
            {vehicleTypes.length === 0 && <li className={styles.empty}>Nenhum tipo cadastrado.</li>}
            {vehicleTypes.map((t) => (
              <li key={t.id} className={styles.item}>
                <span>{t.name}</span>
                <button
                  type="button"
                  className={styles.deleteBtn}
                  onClick={() => handleDelete(t)}
                  disabled={busy}
                  aria-label={`Excluir ${t.name}`}
                >
                  <Trash2 size={14} />
                </button>
              </li>
            ))}
          </ul>

          <div className={styles.addRow}>
            <input
              className={formStyles.input}
              placeholder="Novo tipo (ex.: Ônibus)"
              value={newName}
              maxLength={60}
              onChange={(e) => setNewName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault()
                  handleCreate()
                }
              }}
            />
            <button
              type="button"
              className={styles.addBtn}
              onClick={handleCreate}
              disabled={busy || newName.trim().length < 2}
            >
              <Plus size={14} /> Adicionar
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
