/*
  Warnings:

  - The values [PROPOSTA,CONCLUIDO,PERDIDO] on the enum `DemandStatus` will be removed. If these variants are still used in the database, this will fail.

*/
-- AlterEnum
BEGIN;
CREATE TYPE "DemandStatus_new" AS ENUM ('QUALIFICACAO', 'ANALISE', 'AGENDAMENTO');
ALTER TABLE "public"."DemandPipeline" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "DemandPipeline" ALTER COLUMN "status" TYPE "DemandStatus_new" USING ("status"::text::"DemandStatus_new");
ALTER TYPE "DemandStatus" RENAME TO "DemandStatus_old";
ALTER TYPE "DemandStatus_new" RENAME TO "DemandStatus";
DROP TYPE "public"."DemandStatus_old";
ALTER TABLE "DemandPipeline" ALTER COLUMN "status" SET DEFAULT 'QUALIFICACAO';
COMMIT;
