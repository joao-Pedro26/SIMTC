-- AlterTable
ALTER TABLE "PracticalAssessment" ADD COLUMN     "score" DOUBLE PRECISION;

-- AlterTable
ALTER TABLE "TrainingParticipant" ADD COLUMN     "assignedConsultantId" TEXT;

-- AddForeignKey
ALTER TABLE "TrainingParticipant" ADD CONSTRAINT "TrainingParticipant_assignedConsultantId_fkey" FOREIGN KEY ("assignedConsultantId") REFERENCES "Consultant"("id") ON DELETE SET NULL ON UPDATE CASCADE;
