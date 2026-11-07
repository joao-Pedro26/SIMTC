/**
 * Lista de municípios do Brasil via API de Localidades do IBGE (gratuita, sem
 * chave, CORS liberado). Uma única chamada traz todos (~5.570); o resultado
 * fica em cache no módulo para não repetir a requisição entre formulários.
 */
export interface IbgeCity {
  name: string
  uf: string
  /** Nome sem acentos e em minúsculas, pré-calculado para a busca. */
  search: string
}

const IBGE_URL = 'https://servicodados.ibge.gov.br/api/v1/localidades/municipios?orderBy=nome'

export function normalizeText(value: string): string {
  return value.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim()
}

interface IbgeMunicipioRaw {
  nome: string
  microrregiao?: { mesorregiao?: { UF?: { sigla?: string } } } | null
  'regiao-imediata'?: { 'regiao-intermediaria'?: { UF?: { sigla?: string } } } | null
}

let cache: Promise<IbgeCity[]> | null = null

export function loadIbgeCities(): Promise<IbgeCity[]> {
  if (!cache) {
    cache = fetch(IBGE_URL)
      .then((res) => {
        if (!res.ok) throw new Error(`IBGE respondeu ${res.status}`)
        return res.json() as Promise<IbgeMunicipioRaw[]>
      })
      .then((raw) =>
        raw
          .map((m) => ({
            name: m.nome,
            uf:
              m.microrregiao?.mesorregiao?.UF?.sigla ??
              m['regiao-imediata']?.['regiao-intermediaria']?.UF?.sigla ??
              '',
            search: normalizeText(m.nome),
          }))
          .filter((c) => c.uf !== ''),
      )
      .catch((err) => {
        cache = null // permite tentar de novo na próxima abertura
        throw err
      })
  }
  return cache
}

/** Cidades que começam com o texto digitado vêm antes das que apenas o contêm. */
export function searchCities(cities: IbgeCity[], query: string, uf?: string, limit = 8): IbgeCity[] {
  const q = normalizeText(query)
  if (!q) return []
  const pool = uf ? cities.filter((c) => c.uf === uf) : cities
  const starts: IbgeCity[] = []
  const contains: IbgeCity[] = []
  for (const c of pool) {
    if (c.search.startsWith(q)) starts.push(c)
    else if (c.search.includes(q)) contains.push(c)
    if (starts.length >= limit) break
  }
  return [...starts, ...contains].slice(0, limit)
}
