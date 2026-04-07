-- Add commission and payable fields for user-agent transactions
ALTER TABLE "AgentTransaction"
ADD COLUMN "agentCommission" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "totalPaid" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "agentReceived" INTEGER NOT NULL DEFAULT 0;

-- Backfill existing rows so reads remain consistent
UPDATE "AgentTransaction"
SET
  "agentCommission" = CASE WHEN "amount" >= 1000 THEN ROUND("amount" * 0.005)::INTEGER ELSE 0 END,
  "totalPaid" = "amount" + CASE WHEN "amount" >= 1000 THEN ROUND("amount" * 0.005)::INTEGER ELSE 0 END,
  "agentReceived" = "amount" + CASE WHEN "amount" >= 1000 THEN ROUND("amount" * 0.005)::INTEGER ELSE 0 END;
