/*
  Warnings:

  - You are about to drop the `AlertEvent` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropTable
DROP TABLE "AlertEvent";

-- CreateTable
CREATE TABLE "Alert" (
    "id" TEXT NOT NULL,
    "alertId" TEXT NOT NULL,
    "severity" TEXT NOT NULL,
    "magnitude" DOUBLE PRECISION NOT NULL,
    "location" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "distanceKm" DOUBLE PRECISION,
    "lat" DOUBLE PRECISION NOT NULL,
    "lng" DOUBLE PRECISION NOT NULL,
    "nodeId" TEXT,
    "timestamp" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Alert_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Alert_alertId_key" ON "Alert"("alertId");
