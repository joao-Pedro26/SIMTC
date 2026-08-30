-- Baseline migration (created 27/08/2026): documents columns that already exist in
-- production (added previously via `prisma db push`, never captured as a migration file).
-- This migration is meant to be marked as applied via `prisma migrate resolve --applied`,
-- NOT executed — the columns are already present in the database.
ALTER TABLE "PracticalAssessment" ADD COLUMN IF NOT EXISTS "reportPdfUrl" TEXT;
ALTER TABLE "PracticalAssessment" ADD COLUMN IF NOT EXISTS "reportGeneratedAt" TIMESTAMP(3);
