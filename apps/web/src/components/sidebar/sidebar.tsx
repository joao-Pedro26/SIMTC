'use client'

import Image from 'next/image'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import {
  LayoutDashboard,
  Building2,
  Users,
  BookOpen,
  ClipboardCheck,
  KanbanSquare,
  CalendarCheck,
  BarChart3,
  UserRound,
  LogOut,
  type LucideIcon,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { logoutAction } from '@/app/actions/auth'
import { useCurrentUser, type Role } from '@/components/current-user-context'
import styles from './sidebar.module.css'

// ─── Usuário logado ─────────────────────────────────────────

const roleLabels: Record<string, string> = {
  ADMIN: 'Admin',
  CONSULTANT: 'Consultor',
  CLIENT: 'Cliente',
}

function getInitials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  if (parts.length === 0) return '?'
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
}

// ─── Tipos ───────────────────────────────────────────────────

interface NavItem {
  name: string
  href: string
  icon: LucideIcon
  roles: Role[]
}

interface NavSection {
  label: string
  items: NavItem[]
}

// ─── Estrutura de navegação ────────────────────────────────────
// Cada item declara quais papéis podem vê-lo. O Sidebar filtra os
// itens de acordo com o papel do usuário logado (`me.role`) e some
// com a seção inteira se nenhum item dela sobrar visível. CONSULTANT
// enxerga Empresas/Cursos/Categ. Avaliação/Treinamentos em modo
// somente-leitura (a página trava criação/edição/exclusão).

const topItem: NavItem = {
  name: 'Dashboard',
  href: '/dashboard',
  icon: LayoutDashboard,
  roles: ['ADMIN'],
}

const navSections: NavSection[] = [
  {
    label: 'Cadastros',
    items: [
      { name: 'Empresas',          href: '/companies',              icon: Building2,      roles: ['ADMIN', 'CONSULTANT'] },
      { name: 'Consultores',       href: '/consultants',            icon: Users,          roles: ['ADMIN'] },
      { name: 'Cursos',            href: '/courses',                icon: BookOpen,       roles: ['ADMIN', 'CONSULTANT'] },
      { name: 'Categ. Avaliação',  href: '/assessment-categories',  icon: ClipboardCheck, roles: ['ADMIN', 'CONSULTANT'] },
    ],
  },
  {
    label: 'Operacional',
    items: [
      { name: 'Funil de Demandas', href: '/demand-pipeline',    icon: KanbanSquare,  roles: ['ADMIN'] },
      { name: 'Treinamentos',      href: '/training-sessions',  icon: CalendarCheck, roles: ['ADMIN', 'CONSULTANT'] },
    ],
  },
  {
    label: 'Análise',
    items: [
      { name: 'Relatórios', href: '/reports', icon: BarChart3, roles: ['ADMIN'] },
    ],
  },
  {
    label: 'Consultor',
    items: [
      { name: 'Meu Perfil', href: '/profile', icon: UserRound, roles: ['CONSULTANT'] },
    ],
  },
  {
    label: 'Portal',
    items: [
      { name: 'Minha Empresa', href: '/my-company', icon: Building2, roles: ['CLIENT'] },
    ],
  },
]

// ─── Sub-componente de link ───────────────────────────────────

function NavLink({ item, pathname }: { item: NavItem; pathname: string }) {
  const isActive = pathname === item.href || pathname.startsWith(item.href + '/')
  const Icon = item.icon

  return (
    <Link
      href={item.href}
      className={cn(styles.navLink, isActive && styles.active)}
    >
      <Icon size={22} className={styles.navIcon} />
      <span className={styles.navLinkText}>{item.name}</span>
    </Link>
  )
}

// ─── Componente principal ─────────────────────────────────────

export function Sidebar() {
  const pathname = usePathname()
  const { me } = useCurrentUser()

  // Enquanto `me` ainda não carregou, não mostra nada — evita "piscar"
  // itens de outro papel antes de sabermos quem está logado.
  const role = me?.role
  const visibleSections = navSections
    .map((section) => ({
      ...section,
      items: section.items.filter((item) => role && item.roles.includes(role)),
    }))
    .filter((section) => section.items.length > 0)
  const showTopItem = !!role && topItem.roles.includes(role)

  return (
    <aside className={styles.sidebar}>

      {/* Logo */}
      <div className={styles.logoArea}>
        <Image
          src="/logo-simtc.png"
          alt="SIM Treinamentos"
          width={48}
          height={48}
          className={styles.logoImg}
          priority
        />
        <div className={styles.logoInfo}>
          <p className={styles.logoName}>SIM Treinamentos</p>
          <p className={styles.logoSub}>Sistema de gestão</p>
        </div>
      </div>

      {/* Navegação */}
      <nav className={styles.nav}>

        {/* Dashboard — item de topo fora das seções (só ADMIN) */}
        {showTopItem && <NavLink item={topItem} pathname={pathname} />}

        {/* Seções agrupadas, filtradas pelo papel do usuário logado */}
        {visibleSections.map((section) => (
          <div key={section.label} className={styles.section}>
            <p className={styles.sectionLabel}>{section.label}</p>
            {section.items.map((item) => (
              <NavLink key={item.href} item={item} pathname={pathname} />
            ))}
          </div>
        ))}
      </nav>

      {/* Usuário + logout */}
      <div className={styles.userArea}>
        <div className={styles.userRow}>
          <div className={styles.avatar}>{me ? getInitials(me.name) : '...'}</div>
          <div className={styles.userInfo}>
            <p className={styles.userName}>{me?.name ?? 'Carregando...'}</p>
            <p className={styles.userRole}>{me ? (roleLabels[me.role] ?? me.role) : ''}</p>
          </div>
          <form action={logoutAction}>
            <button type="submit" title="Sair" className={styles.logoutBtn}>
              <LogOut size={15} />
            </button>
          </form>
        </div>
      </div>
    </aside>
  )
}
