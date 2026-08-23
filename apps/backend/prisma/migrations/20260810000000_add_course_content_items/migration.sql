-- Migration: add contentItems to Course
-- Array de { left: string, right?: string, leftBold?: boolean, rightBold?: boolean }

ALTER TABLE "Course" ADD COLUMN IF NOT EXISTS "contentItems" JSONB;
