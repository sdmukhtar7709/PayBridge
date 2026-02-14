/*
  Warnings:

  - You are about to drop the column `storeAddress` on the `AgentProfile` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "AgentProfile" DROP COLUMN "storeAddress",
ADD COLUMN     "locationName" TEXT;
