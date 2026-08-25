'use client'

import { useState } from 'react'
import { createPortal } from 'react-dom'
import { Plus, Trash2, Eye, X } from 'lucide-react'
import styles from './content-items-editor.module.css'

export interface ContentItem {
  left: string
  right: string
  leftBold: boolean
  rightBold: boolean
}

// ── Preview modal ────────────────────────────────────────────────────────────

function PreviewModal({ items, onClose }: { items: ContentItem[]; onClose: () => void }) {
  return createPortal(
    <div className={styles.overlay} onClick={onClose}>
      <div className={styles.previewModal} onClick={(e) => e.stopPropagation()}>

        <div className={styles.previewModalHeader}>
          <span className={styles.previewModalTitle}>Preview — Conteúdo Programático</span>
          <button type="button" className={styles.previewCloseBtn} onClick={onClose}>
            <X size={16} />
          </button>
        </div>

        <div className={styles.previewBody}>
          <div className={styles.certBox}>

            <div className={styles.certBoxHeader}>
              <img src="/logo-simtc.png" alt="SIM Treinamentos" className={styles.certLogo} />
              <span className={styles.certBoxTitle}>Conteúdo programático.</span>
            </div>

            <table className={styles.certTable}>
              <tbody>
                {items.length === 0 ? (
                  <tr>
                    <td colSpan={2} className={styles.certEmptyCell}>
                      Nenhum item cadastrado ainda.
                    </td>
                  </tr>
                ) : (
                  items.map((item, i) => (
                    <tr key={i}>
                      <td className={`${styles.certCell} ${item.leftBold ? styles.certCellBold : ''}`}>
                        {item.left || <span className={styles.emptyCellText}>—</span>}
                      </td>
                      <td className={`${styles.certCell} ${item.rightBold ? styles.certCellBold : ''}`}>
                        {item.right || <span className={styles.emptyCellText}>—</span>}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>

            <div className={styles.certBoxFooter}>
              <span className={styles.certFooterInfo}>Responsável técnico</span>
              <span className={styles.certFooterInsta}>📷 SIMTRANSITO</span>
              <div className={styles.certSigLine} />
            </div>

          </div>

          <p className={styles.previewNote}>
            Preview ilustrativo. No certificado gerado, a onda de fundo e proporções seguem o layout A4 paisagem.
          </p>
        </div>

      </div>
    </div>,
    document.body,
  )
}

// ── Editor ───────────────────────────────────────────────────────────────────

interface ContentItemsEditorProps {
  items: ContentItem[]
  onChange: (items: ContentItem[]) => void
}

export function ContentItemsEditor({ items, onChange }: ContentItemsEditorProps) {
  const [showPreview, setShowPreview] = useState(false)

  function addRow() {
    onChange([...items, { left: '', right: '', leftBold: false, rightBold: false }])
  }

  function removeRow(index: number) {
    onChange(items.filter((_, i) => i !== index))
  }

  function updateRow(index: number, field: keyof ContentItem, value: string | boolean) {
    onChange(items.map((item, i) => (i === index ? { ...item, [field]: value } : item)))
  }

  return (
    <div className={styles.wrapper}>
      <div className={styles.header}>
        <span className={styles.label}>Conteúdo Programático:</span>
        <div className={styles.headerActions}>
          <button
            type="button"
            className={styles.eyeBtn}
            onClick={() => setShowPreview(true)}
            title="Visualizar preview da tabela no certificado"
          >
            <Eye size={14} />
          </button>
          <button type="button" className={styles.addBtn} onClick={addRow}>
            <Plus size={13} />
            Adicionar linha
          </button>
        </div>
      </div>

      {items.length === 0 ? (
        <p className={styles.empty}>
          Nenhum item cadastrado. Clique em &quot;Adicionar linha&quot; para começar.
        </p>
      ) : (
        <div className={styles.listWrapper}>
          <div className={styles.colHeaders}>
            <span>Coluna esquerda</span>
            <span>Coluna direita</span>
          </div>
          <div className={styles.list}>
            {items.map((item, index) => (
              <div key={index} className={styles.row}>
                <div className={styles.cellGroup}>
                  <input
                    className={styles.cellInput}
                    value={item.left}
                    onChange={(e) => updateRow(index, 'left', e.target.value)}
                    placeholder="Texto esquerdo"
                  />
                  <button
                    type="button"
                    className={`${styles.boldBtn} ${item.leftBold ? styles.boldActive : ''}`}
                    onClick={() => updateRow(index, 'leftBold', !item.leftBold)}
                    title="Negrito"
                  >
                    B
                  </button>
                </div>

                <div className={styles.cellGroup}>
                  <input
                    className={styles.cellInput}
                    value={item.right}
                    onChange={(e) => updateRow(index, 'right', e.target.value)}
                    placeholder="Texto direito"
                  />
                  <button
                    type="button"
                    className={`${styles.boldBtn} ${item.rightBold ? styles.boldActive : ''}`}
                    onClick={() => updateRow(index, 'rightBold', !item.rightBold)}
                    title="Negrito"
                  >
                    B
                  </button>
                </div>

                <button
                  type="button"
                  className={styles.removeBtn}
                  onClick={() => removeRow(index)}
                  aria-label="Remover linha"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {showPreview && (
        <PreviewModal items={items} onClose={() => setShowPreview(false)} />
      )}
    </div>
  )
}
