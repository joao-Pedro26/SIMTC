'use client'

// Rota de teste do modal de assinatura. REMOVER na Task 11.

import { useRef, useState } from 'react'
import { SignatureModal } from '@/components/signature-modal/signature-modal'

interface SignatureResult {
  url: string
  sizeKb: string
  width: number
  height: number
}

export default function DevSignaturePage() {
  const [open, setOpen] = useState(false)
  const [result, setResult] = useState<SignatureResult | null>(null)
  const currentUrl = useRef<string | null>(null)

  function handleConfirm(blob: Blob, previewUrl: string) {
    setOpen(false)
    if (currentUrl.current) URL.revokeObjectURL(currentUrl.current)
    currentUrl.current = previewUrl

    const img = new Image()
    img.onload = () => {
      setResult({
        url: previewUrl,
        sizeKb: (blob.size / 1024).toFixed(1),
        width: img.naturalWidth,
        height: img.naturalHeight,
      })
    }
    img.src = previewUrl
  }

  return (
    <main style={{ padding: '2rem', fontFamily: 'system-ui, sans-serif', maxWidth: 640 }}>
      <h1 style={{ fontSize: '1.25rem', marginBottom: '1rem' }}>Teste do modal de assinatura</h1>

      <button
        type="button"
        onClick={() => setOpen(true)}
        style={{ padding: '0.625rem 1.25rem', borderRadius: 8, border: 'none', background: '#38bec8', color: '#fff', fontWeight: 600, cursor: 'pointer' }}
      >
        Assinar
      </button>

      {result && (
        <section style={{ marginTop: '1.5rem' }}>
          <div style={{ border: '1px solid #e2e8f0', borderRadius: 8, background: '#fff', padding: '1rem', display: 'inline-block' }}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={result.url} alt="Prévia da assinatura" />
          </div>
          <p style={{ marginTop: '0.75rem', fontSize: '0.875rem', color: '#475569' }}>
            Tamanho: {result.sizeKb} KB · Dimensões: {result.width}×{result.height} px
          </p>
        </section>
      )}

      <SignatureModal open={open} onCancel={() => setOpen(false)} onConfirm={handleConfirm} />
    </main>
  )
}
