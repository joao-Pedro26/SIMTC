const MARGIN_CSS_PX = 8
const MAX_WIDTH = 600
const MAX_HEIGHT = 200

/**
 * Recorta o espaço transparente em volta do traço (margem de 8 px CSS),
 * reduz para no máximo 600×200 mantendo a proporção e devolve um PNG transparente.
 * Retorna null se o canvas não tiver nenhum pixel desenhado.
 */
export async function cropAndScaleSignature(canvas: HTMLCanvasElement): Promise<Blob | null> {
  const { width, height } = canvas
  if (!width || !height) return null

  const ctx = canvas.getContext('2d', { willReadFrequently: true })
  if (!ctx) return null

  const pixels = ctx.getImageData(0, 0, width, height).data

  let minX = width
  let minY = height
  let maxX = -1
  let maxY = -1

  for (let y = 0; y < height; y++) {
    const rowOffset = y * width * 4
    for (let x = 0; x < width; x++) {
      if (pixels[rowOffset + x * 4 + 3] === 0) continue
      if (x < minX) minX = x
      if (x > maxX) maxX = x
      if (y < minY) minY = y
      if (y > maxY) maxY = y
    }
  }

  if (maxX < 0) return null

  // O canvas está em pixels de dispositivo; a margem é de 8 px CSS convertida para esses pixels.
  const ratio = canvas.clientWidth ? width / canvas.clientWidth : 1
  const margin = Math.round(MARGIN_CSS_PX * ratio)

  const sx = Math.max(0, minX - margin)
  const sy = Math.max(0, minY - margin)
  const sw = Math.min(width, maxX + 1 + margin) - sx
  const sh = Math.min(height, maxY + 1 + margin) - sy

  const scale = Math.min(1, MAX_WIDTH / sw, MAX_HEIGHT / sh)
  const dw = Math.max(1, Math.round(sw * scale))
  const dh = Math.max(1, Math.round(sh * scale))

  const output = document.createElement('canvas')
  output.width = dw
  output.height = dh
  const outputCtx = output.getContext('2d')
  if (!outputCtx) return null

  outputCtx.imageSmoothingEnabled = true
  outputCtx.imageSmoothingQuality = 'high'
  outputCtx.drawImage(canvas, sx, sy, sw, sh, 0, 0, dw, dh)

  return new Promise((resolve) => {
    output.toBlob((blob) => resolve(blob), 'image/png')
  })
}
