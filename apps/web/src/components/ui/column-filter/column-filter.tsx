'use client'

import { useState, useRef, useEffect } from 'react'
import { ChevronDown } from 'lucide-react'
import styles from './column-filter.module.css'

interface TextFilterProps {
  type: 'text'
  label: string
  value: string
  onChange: (v: string) => void
  className?: string
}

interface SelectFilterProps {
  type: 'select'
  label: string
  value: string
  onChange: (v: string) => void
  options: { label: string; value: string }[]
  className?: string
}

type ColumnFilterProps = TextFilterProps | SelectFilterProps

export function ColumnFilter(props: ColumnFilterProps) {
  const { label, value, onChange, className } = props
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLTableCellElement>(null)
  const isActive = value !== ''

  // Close on outside click
  useEffect(() => {
    if (!open) return
    function handle(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false)
      }
    }
    document.addEventListener('mousedown', handle)
    return () => document.removeEventListener('mousedown', handle)
  }, [open])

  return (
    <th ref={ref} className={`${styles.th} ${className ?? ''}`}>
      <button
        className={`${styles.trigger} ${open ? styles.open : ''} ${isActive ? styles.active : ''}`}
        onClick={() => setOpen((v) => !v)}
      >
        {label}
        {isActive && <span className={styles.filterDot} />}
        <ChevronDown size={12} className={styles.chevron} />
      </button>

      {open && (
        <div className={styles.dropdown}>
          {props.type === 'text' ? (
            <div className={styles.textWrap}>
              <input
                autoFocus
                className={styles.textInput}
                value={value}
                onChange={(e) => onChange(e.target.value)}
                placeholder={`Filtrar ${label.toLowerCase()}...`}
              />
              {value && (
                <button
                  className={styles.clearBtn}
                  onClick={() => { onChange(''); setOpen(false) }}
                >
                  Limpar filtro
                </button>
              )}
            </div>
          ) : (
            <div className={styles.options}>
              <button
                className={`${styles.option} ${value === '' ? styles.optionActive : ''}`}
                onClick={() => { onChange(''); setOpen(false) }}
              >
                <span className={styles.optionCheck} />
                Todos
              </button>
              {props.options.map((opt) => (
                <button
                  key={opt.value}
                  className={`${styles.option} ${value === opt.value ? styles.optionActive : ''}`}
                  onClick={() => { onChange(opt.value); setOpen(false) }}
                >
                  <span className={styles.optionCheck} />
                  {opt.label}
                </button>
              ))}
            </div>
          )}
        </div>
      )}
    </th>
  )
}
