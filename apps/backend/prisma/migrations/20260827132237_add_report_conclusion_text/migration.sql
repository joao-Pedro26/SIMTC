-- DropForeignKey
ALTER TABLE "DemandPipeline" DROP CONSTRAINT "DemandPipeline_consultantId_fkey";

-- DropForeignKey
ALTER TABLE "PracticalAssessment" DROP CONSTRAINT "PracticalAssessment_consultantId_fkey";

-- DropForeignKey
ALTER TABLE "TrainingSession" DROP CONSTRAINT "TrainingSession_responsibleConsultantId_fkey";

-- CreateTable
CREATE TABLE "ReportConclusionText" (
    "id" TEXT NOT NULL,
    "minPercent" INTEGER NOT NULL,
    "maxPercent" INTEGER NOT NULL,
    "text" TEXT NOT NULL,

    CONSTRAINT "ReportConclusionText_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ReportConclusionText_minPercent_maxPercent_key" ON "ReportConclusionText"("minPercent", "maxPercent");

-- AddForeignKey
ALTER TABLE "DemandPipeline" ADD CONSTRAINT "DemandPipeline_consultantId_fkey" FOREIGN KEY ("consultantId") REFERENCES "Consultant"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingSession" ADD CONSTRAINT "TrainingSession_responsibleConsultantId_fkey" FOREIGN KEY ("responsibleConsultantId") REFERENCES "Consultant"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PracticalAssessment" ADD CONSTRAINT "PracticalAssessment_consultantId_fkey" FOREIGN KEY ("consultantId") REFERENCES "Consultant"("id") ON DELETE SET NULL ON UPDATE CASCADE;
