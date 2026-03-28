-- AlterTable
ALTER TABLE "AgentTransaction" ADD COLUMN     "agentConfirmOtp" TEXT,
ADD COLUMN     "agentConfirmedAt" TIMESTAMP(3),
ADD COLUMN     "approvedAt" TIMESTAMP(3),
ADD COLUMN     "confirmOtpExpires" TIMESTAMP(3),
ADD COLUMN     "userConfirmOtp" TEXT,
ADD COLUMN     "userConfirmedAt" TIMESTAMP(3);
