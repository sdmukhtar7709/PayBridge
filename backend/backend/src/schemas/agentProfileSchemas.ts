import { z } from "zod";

// For agent creation, user may set optional display name, phone, etc. But isVerified/available default to false
export const agentProfileCreateSchema = z.object({
  cashLimit: z.number().min(0).default(0),
  // Optional: Add public fields like displayName, phone
  // displayName: z.string().min(2).max(50).optional(),
});

export type AgentProfileCreateInput = z.infer<typeof agentProfileCreateSchema>;

// For PATCH: agent wants to self-update
export const agentProfilePatchSchema = z.object({
  cashLimit: z.number().int().optional(),
  available: z.boolean().optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  locationName: z.string().max(255).optional(),
});

export type AgentProfileUpdateInput = z.infer<typeof agentProfilePatchSchema>;
