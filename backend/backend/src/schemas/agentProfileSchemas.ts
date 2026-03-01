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
  cashLimit: z.coerce.number().min(0).optional(),
  available: z.boolean().optional(),
  city: z.string().trim().max(50).optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  locationName: z.string().max(255).optional(),
});

export type AgentProfileUpdateInput = z.infer<typeof agentProfilePatchSchema>;

export const userProfilePatchSchema = z.object({
  name: z.string().trim().min(1).max(120).optional(),
  firstName: z.string().trim().max(80).optional(),
  lastName: z.string().trim().max(80).optional(),
  phone: z.string().trim().max(30).optional(),
  gender: z.string().trim().max(30).optional(),
  maritalStatus: z.string().trim().max(30).optional(),
  age: z.union([z.coerce.number().int().min(1).max(120), z.null()]).optional(),
  address: z.string().trim().max(255).optional(),
  profileImage: z.string().trim().max(8000000).optional(),
});

export const agentManageProfileSchema = z
  .object({
    user: userProfilePatchSchema.optional(),
    agentProfile: agentProfilePatchSchema.optional(),
  })
  .refine((value) => Boolean(value.user) || Boolean(value.agentProfile), {
    message: "Provide at least one of user or agentProfile",
    path: ["user"],
  });

export type UserProfilePatchInput = z.infer<typeof userProfilePatchSchema>;
export type AgentManageProfileInput = z.infer<typeof agentManageProfileSchema>;
