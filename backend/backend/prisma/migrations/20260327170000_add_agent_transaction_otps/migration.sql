-- Add new OTP columns as nullable to avoid breaking existing rows
ALTER TABLE "AgentTransaction" ADD COLUMN "requestOtp" TEXT;
ALTER TABLE "AgentTransaction" ADD COLUMN "requestOtpExpires" TIMESTAMP(3);

-- Backfill from legacy columns
UPDATE "AgentTransaction"
SET "requestOtp" = COALESCE("requestOtp", "otp"),
    "requestOtpExpires" = COALESCE("requestOtpExpires", "otpExpires")
WHERE "requestOtp" IS NULL;

-- Enforce NOT NULL on requestOtp after backfill
ALTER TABLE "AgentTransaction" ALTER COLUMN "requestOtp" SET NOT NULL;

-- Drop legacy columns
ALTER TABLE "AgentTransaction" DROP COLUMN "otp";
ALTER TABLE "AgentTransaction" DROP COLUMN "otpExpires";
