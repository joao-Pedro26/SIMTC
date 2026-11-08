-- CreateTable
CREATE TABLE "CourseAssessmentCategory" (
    "courseId" TEXT NOT NULL,
    "categoryId" TEXT NOT NULL,

    CONSTRAINT "CourseAssessmentCategory_pkey" PRIMARY KEY ("courseId","categoryId")
);

-- CreateIndex
CREATE INDEX "CourseAssessmentCategory_categoryId_idx" ON "CourseAssessmentCategory"("categoryId");

-- AddForeignKey
ALTER TABLE "CourseAssessmentCategory" ADD CONSTRAINT "CourseAssessmentCategory_courseId_fkey" FOREIGN KEY ("courseId") REFERENCES "Course"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CourseAssessmentCategory" ADD CONSTRAINT "CourseAssessmentCategory_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "AssessmentCategory"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Backfill: até aqui todo curso usava todos os tópicos. Os cursos existentes
-- continuam assim até o admin editar a seleção de cada um.
INSERT INTO "CourseAssessmentCategory" ("courseId", "categoryId")
SELECT c."id", ac."id"
FROM "Course" c
CROSS JOIN "AssessmentCategory" ac
ON CONFLICT DO NOTHING;
