'use client'

import { Search } from 'lucide-react'
import styles from './input-search.module.css'

interface InputSearchProps {
  value: string
  onChange: (value: string) => void
  placeholder?: string
}

export function InputSearch({ value, onChange, placeholder = 'Buscar...' }: InputSearchProps) {
  return (
    <div className={styles.wrapper}>
      <Search size={15} className={styles.icon} />
      <input
        type="search"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className={styles.input}
      />
    </div>
  )
}
