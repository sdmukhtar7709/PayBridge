import { z } from "zod";

export const transactionCreateSchema = z.object({
  agentId: z.string().uuid(),
  amount: z.number().int().min(100).max(100000)
});