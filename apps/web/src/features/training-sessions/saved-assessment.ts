/**
 * Avaliação prática já salva (`GET /practical-assessments/by-participant/:id`)
 * e a conversão para o estado do checklist do `AssessmentDrawer`, usado tanto
 * para avaliar quanto para só visualizar.
 */

/** Falta marcada no checklist, por infração. */
export interface SelectedNote {
  infractionNoteId: string
  noteType: 'B' | 'PM' | 'M'
  deduction: number
  categoryId: string
  observation?: string
}

export interface SavedAssessmentItem {
  id: string
  observation: string | null
  infractionNote: {
    id: string
    noteType: 'B' | 'PM' | 'M'
    deduction: number
    infraction: { id: string; categoryId: string }
  }
}

export interface SavedAssessment {
  id: string
  score: number | null
  date: string
  startTime: string
  endTime: string | null
  consultant: { id: string; name: string } | null
  items: SavedAssessmentItem[]
}

/**
 * Só os tópicos vinculados ao curso entram no checklist e na nota. Curso sem
 * nenhum tópico vinculado cai em todos (mesma regra do backend:
 * `findCourseCategories`).
 */
export function categoriesForCourse<C extends { courseIds?: string[] }>(all: C[], courseId: string): C[] {
  const linked = all.filter((c) => c.courseIds?.includes(courseId))
  return linked.length > 0 ? linked : all
}

/** Uma entrada por infração (chave = id da infração), como o checklist guarda. */
export function selectionsFromSaved(items: SavedAssessmentItem[]): Map<string, SelectedNote> {
  const selections = new Map<string, SelectedNote>()
  for (const item of items) {
    const { infractionNote: note } = item
    selections.set(note.infraction.id, {
      infractionNoteId: note.id,
      noteType: note.noteType,
      deduction: note.deduction,
      categoryId: note.infraction.categoryId,
      observation: item.observation ?? undefined,
    })
  }
  return selections
}

/**
 * Tópicos para visualizar uma avaliação salva: os do curso hoje e, depois
 * deles, os que têm falta salva mas não estão mais vinculados ao curso — assim
 * nenhuma falta some da tela.
 */
export function categoriesForReview<C extends { id: string; courseIds?: string[] }>(
  all: C[],
  courseId: string,
  items: SavedAssessmentItem[],
): C[] {
  const course = categoriesForCourse(all, courseId)
  const shown = new Set(course.map((c) => c.id))
  const withFaults = new Set(items.map((i) => i.infractionNote.infraction.categoryId))
  const extra = all.filter((c) => !shown.has(c.id) && withFaults.has(c.id))
  return [...course, ...extra]
}
