import { Request, Response } from "express";
import prisma from "../lib/prisma.js";
import { adminAgentUpdateSchema } from "../schemas/adminAgentSchemas.js";

// PATCH /admin/agents/:id
export async function adminUpdateAgent(req: Request, res: Response) {
  const { id } = req.params;

  // Only allow verified/banned patch
  const parsed = adminAgentUpdateSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  // Ensure agent exists
  const agent = await prisma.agentProfile.findUnique({ where: { id } });
  if (!agent) return res.status(404).json({ error: "Agent not found" });

  // Update agent with allowed fields
  const updated = await prisma.agentProfile.update({
    where: { id },
    data: parsed.data,
    include: { user: true }
  });

  return res.json(updated);
}
