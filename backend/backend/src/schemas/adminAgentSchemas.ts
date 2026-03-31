import { z } from "zod";

export const adminAgentUpdateSchema = z.object({
  status: z.enum(["pending", "verified", "unverified", "banned"]).optional(),
  isVerified: z.boolean().optional(),
  isBanned: z.boolean().optional()
  // Optionally add other admin-edit fields here
});

export const adminTransactionsQuerySchema = z.object({
  status: z
    .enum(["pending", "approved", "confirmed", "cancelled", "archived"])
    .optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  search: z
    .string()
    .trim()
    .max(120)
    .optional()
    .transform((value) => (value && value.length ? value : undefined)),
  limit: z.coerce.number().int().positive().max(500).default(200),
});

export const adminReportsQuerySchema = z.object({
  days: z.coerce.number().int().min(1).max(90).default(7),
});

export type AdminAgentUpdateInput = z.infer<typeof adminAgentUpdateSchema>;
export type AdminTransactionsQueryInput = z.infer<typeof adminTransactionsQuerySchema>;
export type AdminReportsQueryInput = z.infer<typeof adminReportsQuerySchema>;
