'use client'

import { useEffect } from 'react'
import { usePageTitleContext } from './page-title-context'

interface PageTitleProps {
  title: string
}

export function PageTitle({ title }: PageTitleProps) {
  const { setTitle } = usePageTitleContext()

  useEffect(() => {
    setTitle(title)
    return () => setTitle('')
  }, [title, setTitle])

  return null
}
