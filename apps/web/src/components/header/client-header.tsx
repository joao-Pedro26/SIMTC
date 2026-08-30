'use client'

import Image from 'next/image'
import { LogOut } from 'lucide-react'
import { usePageTitleContext } from './page-title-context'
import { useCurrentUser } from '@/components/current-user-context'
import { logoutAction } from '@/app/actions/auth'
import styles from './client-header.module.css'

// Header próprio do portal do cliente — substitui a combinação Sidebar+Header
// usada pelo admin/consultor. Como o cliente só tem uma seção (Minha Empresa),
// não faz sentido reservar uma sidebar inteira só para navegação; a logo da
// SIMTC e o botão de logout, que antes viviam na Sidebar, migraram pra cá.
export function ClientHeader() {
  const { title } = usePageTitleContext()
  const { me } = useCurrentUser()

  return (
    <header className={styles.header}>
      <div className={styles.brandArea}>
        <Image
          src="/logo-simtc.png"
          alt="SIM Treinamentos"
          width={36}
          height={36}
          className={styles.logoImg}
          priority
        />
        <span className={styles.brandText}>SIM Treinamentos</span>
      </div>

      {title && (
        <div className={styles.pageTitle}>
          <span className={styles.divider}>|</span>
          <span className={styles.pageName}>{title}</span>
        </div>
      )}

      <div className={styles.spacer} />

      <div className={styles.userArea}>
        {me && <span className={styles.userName}>{me.name}</span>}
        <form action={logoutAction}>
          <button type="submit" title="Sair" className={styles.logoutBtn}>
            <LogOut size={16} />
          </button>
        </form>
      </div>
    </header>
  )
}
