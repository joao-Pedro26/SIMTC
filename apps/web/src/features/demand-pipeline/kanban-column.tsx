import { Droppable, Draggable } from '@hello-pangea/dnd'
import { Plus } from 'lucide-react'
import { DemandCard, type Demand } from './demand-card'
import styles from './kanban-column.module.css'

interface KanbanColumnProps {
  id: string
  title: string
  demands: Demand[]
  onCardClick: (demand: Demand) => void
  onAddClick: () => void
}

export function KanbanColumn({ id, title, demands, onCardClick, onAddClick }: KanbanColumnProps) {
  return (
    <div className={styles.column}>
      <div className={styles.columnHeader}>
        <div className={styles.titleRow}>
          <span className={styles.title}>{title}</span>
          <span className={styles.count}>{demands.length}</span>
        </div>
        <button className={styles.addBtn} onClick={onAddClick} title="Adicionar demanda">
          <Plus size={15} />
        </button>
      </div>

      <Droppable droppableId={id}>
        {(provided, snapshot) => (
          <div
            ref={provided.innerRef}
            {...provided.droppableProps}
            className={`${styles.list} ${snapshot.isDraggingOver ? styles.listOver : ''}`}
          >
            {demands.map((demand, index) => (
              <Draggable key={demand.id} draggableId={demand.id} index={index}>
                {(prov, snap) => (
                  <div
                    ref={prov.innerRef}
                    {...prov.draggableProps}
                    {...prov.dragHandleProps}
                    className={`${styles.draggable} ${snap.isDragging ? styles.dragging : ''}`}
                  >
                    <DemandCard demand={demand} onClick={() => onCardClick(demand)} />
                  </div>
                )}
              </Draggable>
            ))}
            {provided.placeholder}

            {demands.length === 0 && !snapshot.isDraggingOver && (
              <div className={styles.empty}>Nenhuma demanda</div>
            )}
          </div>
        )}
      </Droppable>
    </div>
  )
}
