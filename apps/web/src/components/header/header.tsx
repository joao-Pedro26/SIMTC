'use client'

import { usePageTitleContext } from './page-title-context'
import styles from './header.module.css'

export function Header() {
  const { title } = usePageTitleContext()

  return (
    <header className={styles.header}>
      {title && (
        <div className={styles.pageTitle}>
          <span className={styles.pageName}>{title}</span>
          <span className={styles.divider}>|</span>
          <span className={styles.brand}>SIM Treinamentos</span>
        </div>
      )}
    </header>
  )
}
