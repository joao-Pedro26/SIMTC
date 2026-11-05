'use client'

import { useCallback, useEffect, useRef, useState } from 'react'
import SignaturePad, { type PointGroup } from 'signature_pad'
import { cropAndScaleSignature } from './crop-signature'

const MIN_STROKES = 2
const MIN_POINTS = 15

interface InkStats {
  strokes: number
  points: number
}

const EMPTY_INK: InkStats = { strokes: 0, points: 0 }

function measure(data: PointGroup[]): InkStats {
  return {
    strokes: data.length,
    points: data.reduce((total, group) => total + group.points.length, 0),
  }
}

export function useSignaturePad() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const padRef = useRef<SignaturePad | null>(null)
  const [isEmpty, setIsEmpty] = useState(true)
  const [ink, setInk] = useState<InkStats>(EMPTY_INK)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const pad = new SignaturePad(canvas, {
      penColor: '#111111',
      minWidth: 0.8,
      maxWidth: 2.6,
      backgroundColor: 'rgba(0, 0, 0, 0)',
    })
    padRef.current = pad

    const sync = () => {
      setIsEmpty(pad.isEmpty())
      setInk(measure(pad.toData()))
    }

    let lastKey = ''
    // Dimensões CSS anteriores, usadas para reescalar os traços na rotação.
    let lastWidth = 0
    let lastHeight = 0
    // Redimensiona o canvas (rotação, resize da janela) sem perder o desenho:
    // guarda os traços com toData(), reescala x/y pela proporção das dimensões
    // CSS antigas para as novas e redesenha com fromData(). Os pontos ficam em
    // coordenadas CSS, então o contexto recebe scale(ratio) a cada mudança.
    const resize = () => {
      const width = canvas.clientWidth
      const height = canvas.clientHeight
      if (!width || !height) return

      const ratio = Math.max(window.devicePixelRatio || 1, 1)
      const key = `${width}x${height}@${ratio}`
      if (key === lastKey) return
      lastKey = key

      // Sem dimensão anterior (primeira medição) não há o que reescalar.
      const scaleX = lastWidth > 0 ? width / lastWidth : 1
      const scaleY = lastHeight > 0 ? height / lastHeight : 1
      lastWidth = width
      lastHeight = height

      const data = pad.toData().map((group) => ({
        ...group,
        points: group.points.map((point) => ({
          ...point,
          x: point.x * scaleX,
          y: point.y * scaleY,
        })),
      }))

      canvas.width = Math.round(width * ratio)
      canvas.height = Math.round(height * ratio)
      canvas.getContext('2d')?.scale(ratio, ratio)
      pad.fromData(data)
      sync()
    }

    pad.addEventListener('endStroke', sync)

    const observer = typeof ResizeObserver !== 'undefined' ? new ResizeObserver(resize) : null
    observer?.observe(canvas)
    resize()
    sync()

    return () => {
      observer?.disconnect()
      pad.removeEventListener('endStroke', sync)
      pad.off()
      padRef.current = null
    }
  }, [])

  const clear = useCallback(() => {
    padRef.current?.clear()
    setIsEmpty(true)
    setInk(EMPTY_INK)
  }, [])

  const toBlob = useCallback(async (): Promise<Blob | null> => {
    const canvas = canvasRef.current
    const pad = padRef.current
    if (!canvas || !pad || pad.isEmpty()) return null
    return cropAndScaleSignature(canvas)
  }, [])

  return {
    canvasRef,
    isEmpty,
    strokeCount: ink.strokes,
    clear,
    toBlob,
    hasEnoughInk: ink.strokes >= MIN_STROKES || ink.points >= MIN_POINTS,
  }
}
