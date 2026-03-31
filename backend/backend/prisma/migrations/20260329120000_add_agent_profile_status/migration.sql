ALTER TABLE "AgentProfile"
ADD COLUMN "status" TEXT NOT NULL DEFAULT 'pending';

UPDATE "AgentProfile"
SET "status" = CASE
  WHEN "isBanned" = true THEN 'banned'
  WHEN "isVerified" = true THEN 'verified'
  ELSE 'pending'
END;

UPDATE "AgentProfile"
SET
  "isVerified" = CASE WHEN "status" = 'verified' THEN true ELSE false END,
  "isBanned" = CASE WHEN "status" = 'banned' THEN true ELSE false END,
  "available" = CASE WHEN "status" = 'banned' THEN false ELSE "available" END;

ALTER TABLE "AgentProfile"
ADD CONSTRAINT "AgentProfile_status_check"
CHECK ("status" IN ('pending', 'verified', 'unverified', 'banned'));
