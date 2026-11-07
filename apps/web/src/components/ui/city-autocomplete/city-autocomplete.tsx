'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { loadIbgeCities, searchCities, type IbgeCity } from '@/lib/ibge-cities'
import styles from './city-autocomplete.module.css'

interface CityAutocompleteProps {
  value: string
  /** UF atualmente escolhida: restringe as sugestões a esse estado. */
  uf?: string
  /** Chamado ao digitar (uf undefined) ou ao escolher uma sugestão (uf preenchida). */
  onChange: (city: string, uf?: string) => void
  inputClassName?: string
  placeholder?: string
  id?: string
}

/**
 * Campo de cidade com autocompletar (IBGE). Ao escolher uma sugestão devolve
 * também a UF, para o formulário preencher o estado sozinho. Se a API do IBGE
 * estiver fora do ar, continua funcionando como campo de texto livre.
 */
export function CityAutocomplete({ value, uf, onChange, inputClassName, placeholder, id }: CityAutocompleteProps) {
  const [cities, setCities] = useState<IbgeCity[] | null>(null)
  const [open, setOpen] = useState(false)
  const [active, setActive] = useState(0)
  const wrapperRef = useRef<HTMLDivElement>(null)

  // Carrega a lista só quando o campo é usado pela primeira vez.
  function ensureLoaded() {
    if (cities) return
    loadIbgeCities().then(setCities).catch(() => {})
  }

  const suggestions = useMemo(
    () => (cities && open ? searchCities(cities, value, uf || undefined) : []),
    [cities, open, value, uf],
  )

  useEffect(() => {
    function onClickOutside(e: MouseEvent) {
      if (!wrapperRef.current?.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', onClickOutside)
    return () => document.removeEventListener('mousedown', onClickOutside)
  }, [])

  function pick(c: IbgeCity) {
    onChange(c.name, c.uf)
    setOpen(false)
  }

  function onKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (!open || suggestions.length === 0) return
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      setActive((i) => (i + 1) % suggestions.length)
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      setActive((i) => (i - 1 + suggestions.length) % suggestions.length)
    } else if (e.key === 'Enter') {
      e.preventDefault()
      pick(suggestions[active])
    } else if (e.key === 'Escape') {
      setOpen(false)
    }
  }

  return (
    <div className={styles.wrapper} ref={wrapperRef}>
      <input
        id={id}
        className={inputClassName}
        value={value}
        placeholder={placeholder}
        autoComplete="off"
        role="combobox"
        aria-expanded={open && suggestions.length > 0}
        aria-autocomplete="list"
        onFocus={ensureLoaded}
        onChange={(e) => {
          ensureLoaded()
          setActive(0)
          setOpen(true)
          onChange(e.target.value)
        }}
        onKeyDown={onKeyDown}
      />
      {suggestions.length > 0 && (
        <ul className={styles.list} role="listbox">
          {suggestions.map((c, i) => (
            <li
              key={`${c.name}-${c.uf}`}
              role="option"
              aria-selected={i === active}
              className={`${styles.option} ${i === active ? styles.optionActive : ''}`}
              onMouseEnter={() => setActive(i)}
              // mousedown (não click) para disparar antes do blur do input
              onMouseDown={(e) => { e.preventDefault(); pick(c) }}
            >
              <span>{c.name}</span>
              <span className={styles.uf}>{c.uf}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
