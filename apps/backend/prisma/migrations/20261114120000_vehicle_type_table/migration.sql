-- A tabela nova tem o mesmo nome do enum antigo e o Postgres não aceita os dois:
-- renomeia o enum primeiro e dropa no final.
ALTER TYPE "VehicleType" RENAME TO "VehicleType_old";

-- CreateTable
CREATE TABLE "VehicleType" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VehicleType_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "VehicleType_name_key" ON "VehicleType"("name");

-- Os 3 tipos que existiam no enum viram linhas da tabela
INSERT INTO "VehicleType" ("id", "name") VALUES
  ('vehicle_type_leve',   'Veículo Leve'),
  ('vehicle_type_pesado', 'Veículo Pesado'),
  ('vehicle_type_moto',   'Motocicleta');

-- Course: troca o enum pela FK, migrando os valores existentes
ALTER TABLE "Course" ADD COLUMN "vehicleTypeId" TEXT;

UPDATE "Course" SET "vehicleTypeId" = CASE "vehicleType"::text
  WHEN 'LEVE'   THEN 'vehicle_type_leve'
  WHEN 'PESADO' THEN 'vehicle_type_pesado'
  WHEN 'MOTO'   THEN 'vehicle_type_moto'
END;

ALTER TABLE "Course" ALTER COLUMN "vehicleTypeId" SET NOT NULL;
ALTER TABLE "Course" DROP COLUMN "vehicleType";
DROP TYPE "VehicleType_old";

-- AddForeignKey
ALTER TABLE "Course" ADD CONSTRAINT "Course_vehicleTypeId_fkey" FOREIGN KEY ("vehicleTypeId") REFERENCES "VehicleType"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
