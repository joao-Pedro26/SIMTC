import { Prisma } from '@prisma/client';

type Db = Pick<Prisma.TransactionClient, 'assessmentCategory'>;

/**
 * Tópicos (categorias) que valem para a avaliação prática de um curso, na
 * ordem canônica, com a contagem de infrações usada na fórmula do score.
 *
 * Só os tópicos vinculados ao curso entram na nota. Curso sem nenhum tópico
 * vinculado (não deveria acontecer em curso com parte prática — o cadastro
 * exige ao menos 1) cai no comportamento antigo, de todos os tópicos, para
 * a nota nunca ser calculada sobre uma lista vazia. A mesma regra está no
 * web (assessment-drawer) e no app mobile.
 */
export async function findCourseCategories(db: Db, courseId: string) {
  const select = {
    id: true,
    code: true,
    name: true,
    description: true,
    order: true,
    _count: { select: { infractions: true } },
  } satisfies Prisma.AssessmentCategorySelect;

  const linked = await db.assessmentCategory.findMany({
    where: { courses: { some: { courseId } } },
    select,
    orderBy: { order: 'asc' },
  });
  if (linked.length > 0) return linked;

  return db.assessmentCategory.findMany({ select, orderBy: { order: 'asc' } });
}
