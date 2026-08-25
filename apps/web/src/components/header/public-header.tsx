import Image from 'next/image'
import styles from './public-header.module.css'

export function PublicHeader() {
  return (
    <header className={styles.header}>
      <div className={styles.logoSlot}>
        <Image
          src="/logo-simtc.png"
          alt="SIM Treinamentos"
          height={48}
          width={48}
          className={styles.logo}
          priority
        />
      </div>
      <div className={styles.sep} />
      <span className={styles.brand}>SIM Treinamentos</span>
    </header>
  )
}
