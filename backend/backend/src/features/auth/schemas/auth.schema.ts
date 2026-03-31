import { z } from "zod";

export const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  name: z.string().trim().min(1).optional(),
  phone: z.string().trim().min(1).optional(),
});

export const adminRegisterSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  name: z.string().trim().min(1),
  phone: z.string().trim().min(1).optional(),
  registrationCode: z.string().trim().min(4),
});

export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type AdminRegisterInput = z.infer<typeof adminRegisterSchema>;
