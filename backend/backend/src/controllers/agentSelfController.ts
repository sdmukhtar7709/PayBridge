import { Request, Response } from "express";
import prisma from "../lib/prisma.js";
import { agentProfileCreateSchema, agentProfilePatchSchema } from "../schemas/agentProfileSchemas.js";

// POST /agent/profile
export async function createAgentProfile(req: Request, res: Response) {
  const userId = (req as any).user?.id;
  if (!userId) return res.status(401).json({ error: "Unauthorized" });

  // Prevent duplicates: each user can have only one agent profile
  const existing = await prisma.agentProfile.findUnique({ where: { userId } });
  if (existing) return res.status(400).json({ error: "You already have an agent profile." });

  // Validate input (only cashLimit supported for now)
  const parsed = agentProfileCreateSchema.safeParse(req.body);
  if (!parsed.success)
    return res.status(400).json({ error: parsed.error.flatten() });

  // Create with sensible defaults
  const agent = await prisma.agentProfile.create({
    data: {
      userId,
      cashLimit: parsed.data.cashLimit,
      isVerified: false,
      isBanned: false,
      available: false
      // Add more fields as needed
    },
    include: { user: true }
  });
  return res.status(201).json(agent);
}

// PATCH /agent/profile
export async function updateAgentProfile(req: Request, res: Response) {
  const userId = (req as any).user?.id;
  if (!userId) return res.status(401).json({ error: "Unauthorized" });

  // Only allow update if agent profile exists
  const agent = await prisma.agentProfile.findUnique({ where: { userId } });
  if (!agent) return res.status(404).json({ error: "You do not have an agent profile." });

  const parsed = agentProfilePatchSchema.safeParse(req.body);
  if (!parsed.success)
    return res.status(400).json({ error: parsed.error.flatten() });

  const updated = await prisma.agentProfile.update({
    where: { userId },
    data: parsed.data,
    include: { user: true }
  });
  return res.json(updated);
}
