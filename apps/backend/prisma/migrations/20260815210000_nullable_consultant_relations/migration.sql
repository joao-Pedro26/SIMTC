-- Permite excluir um consultor de fato: as relações antigas (treinamentos,
-- avaliações e demandas) ficam com o campo de consultor em branco (NULL) em
-- vez de bloquear a exclusão ou exigir arquivamento.

-- AlterTable
ALTER TABLE "TrainingSession" ALTER COLUMN "responsibleConsultantId" DROP NOT NULL;

-- AlterTable
ALTER TABLE "PracticalAssessment" ALTER COLUMN "consultantId" DROP NOT NULL;

-- AlterTable
ALTER TABLE "DemandPipeline" ALTER COLUMN "consultantId" DROP NOT NULL;
