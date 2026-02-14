import { z } from "zod";

export const adminAgentUpdateSchema = z.object({
  isVerified: z.boolean().optional(),
  isBanned: z.boolean().optional()
  // Optionally add other admin-edit fields here
});

export type AdminAgentUpdateInput = z.infer<typeof adminAgentUpdateSchema>;
