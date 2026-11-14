'use client'

import { useState } from 'react'
import { Pencil, Trash2, Eye } from 'lucide-react'
import { ColumnFilter } from '@/components/ui/column-filter/column-filter'
import styles from './course-table.module.css'

export interface Course {
  id: string
  name: string
  practicalHours: number
  theoreticalHours: number
  description: string
  vehicleTypeId?: string
  vehicleTypeName?: string
  contentItems?: any[]
  /** Tópicos de avaliação prática vinculados ao curso */
  categoryIds?: string[]
}

interface CourseTableProps {
  courses: Course[]
  /** Tipos de veículo cadastrados — alimentam o filtro da coluna */
  vehicleTypes: { id: string; name: string }[]
  onEdit: (course: Course) => void
  onDelete: (course: Course) => void
  /** Código (CV, RR, ...) de cada tópico, por id — para a coluna "Tópicos" */
  topicCodes?: Map<string, string>
  /** Modo somente-leitura (ex.: CONSULTANT) — some com a coluna de ações; clique na linha ainda abre visualização */
  readOnly?: boolean
}

export function CourseTable({ courses, vehicleTypes, onEdit, onDelete, topicCodes, readOnly = false }: CourseTableProps) {
  const vehicleOptions = vehicleTypes.map((t) => ({ label: t.name, value: t.id }))
  const [nameFilter,    setNameFilter]    = useState('')
  const [vehicleFilter, setVehicleFilter] = useState('')

  const filtered = courses.filter((c) => {
    const matchName    = c.name.toLowerCase().includes(nameFilter.toLowerCase())
    const matchVehicle = vehicleFilter === '' || c.vehicleTypeId === vehicleFilter
    return matchName && matchVehicle
  })

  if (courses.length === 0) {
    return <p className={styles.empty}>Nenhum curso encontrado.</p>
  }

  return (
    <div className={styles.wrapper}>
      <table className={styles.table}>
        <thead>
          <tr className={styles.headRow}>
            <ColumnFilter
              type="text"
              label="Nome do Curso"
              value={nameFilter}
              onChange={setNameFilter}
              className={styles.th}
            />
            <ColumnFilter
              type="select"
              label="Tipo Veículo"
              value={vehicleFilter}
              onChange={setVehicleFilter}
              options={vehicleOptions}
              className={`${styles.th} ${styles.center}`}
            />
            <th className={`${styles.th} ${styles.center}`}>Horas Práticas</th>
            <th className={`${styles.th} ${styles.center}`}>Horas Teóricas</th>
            <th className={`${styles.th} ${styles.center}`}>Tópicos</th>
            <th className={styles.th}>Descrição</th>
            <th className={styles.th} />
          </tr>
        </thead>
        <tbody>
          {filtered.length === 0 ? (
            <tr>
              <td colSpan={7} className={styles.empty}>
                Nenhum resultado com os filtros aplicados.
              </td>
            </tr>
          ) : (
            filtered.map((c) => (
              <tr key={c.id} className={styles.row}>
                <td className={`${styles.td} ${styles.nameCell}`}>{c.name}</td>
                <td className={`${styles.td} ${styles.center}`}>
                  {c.vehicleTypeName ?? '—'}
                </td>
                <td className={`${styles.td} ${styles.center}`}>{c.practicalHours}h</td>
                <td className={`${styles.td} ${styles.center}`}>{c.theoreticalHours}h</td>
                <td className={`${styles.td} ${styles.center}`}>
                  {c.categoryIds && c.categoryIds.length > 0 && topicCodes
                    ? Array.from(topicCodes)
                        .filter(([id]) => c.categoryIds!.includes(id))
                        .map(([, code]) => code)
                        .join(', ')
                    : '—'}
                </td>
                <td className={styles.td}>
                  <div className={styles.descClamp}>{c.description}</div>
                </td>
                <td className={`${styles.td} ${styles.actions}`}>
                  {readOnly ? (
                    <button
                      className={styles.actionBtn}
                      onClick={() => onEdit(c)}
                      aria-label="Visualizar"
                    >
                      <Eye size={15} />
                    </button>
                  ) : (
                    <>
                      <button
                        className={styles.actionBtn}
                        onClick={() => onEdit(c)}
                        aria-label="Editar"
                      >
                        <Pencil size={15} />
                      </button>
                      <button
                        className={`${styles.actionBtn} ${styles.deleteBtn}`}
                        onClick={() => onDelete(c)}
                        aria-label="Deletar"
                      >
                        <Trash2 size={15} />
                      </button>
                    </>
                  )}
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  )
}
