import { ChevronDown } from 'lucide-react'
import styles from './select.module.css'

interface SelectOption {
  label: string
  value: string
}

interface SelectProps {
  value: string
  onChange: (value: string) => void
  options: SelectOption[]
  placeholder?: string
}

export function Select({ value, onChange, options, placeholder = 'Selecionar' }: SelectProps) {
  return (
    <div className={styles.wrapper}>
      <select
        className={styles.select}
        value={value}
        onChange={(e) => onChange(e.target.value)}
      >
        <option value="">{placeholder}</option>
        {options.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
      <ChevronDown size={15} className={styles.icon} />
    </div>
  )
}
