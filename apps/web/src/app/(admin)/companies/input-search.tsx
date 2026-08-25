'use client'

import { Search } from 'lucide-react'

interface CompaniesInputSearchProps {
  value: string
  onChange: (value: string) => void
  placeholder?: string
}

// Componente de busca local para a listagem de empresas.
// Se precisar de estilos customizados, crie um input-search.module.css nesta pasta.
export function CompaniesInputSearch({
  value,
  onChange,
  placeholder = 'Buscar empresa...',
}: CompaniesInputSearchProps) {
  return (
    <div className="input-search">
      <Search size={15} />
      <input
        type="search"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
      />
    </div>
  )
}
