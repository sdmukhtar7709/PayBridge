import { Router } from "express";
import prisma from "../lib/prisma.js";
import { requireAuth } from "../middleware/auth.js";
import { adminAgentUpdateSchema } from "../schemas/adminAgentSchemas.js";
import { validate } from "../middleware/validate.js";
import { requireRole } from "../middleware/requireRole.js";

// Create router
const router = Router();

// GET: Admin - list all agent profiles
router.get(
  "/agents",
  requireAuth,
  requireRole(["admin"]),
  async (req, res) => {
    const agents = await prisma.agentProfile.findMany({
      include: { user: true },
      orderBy: [{ createdAt: "desc" }]
    });
    res.json(agents);
  }
);

// PATCH: Admin - verify/approve or ban an agent
router.patch(
  "/agents/:id",
  requireAuth,
  requireRole(["admin"]),
  validate(adminAgentUpdateSchema),
  async (req, res) => {
    const { id } = req.params;

    const agent = await prisma.agentProfile.findUnique({ where: { id } });
    if (!agent) return res.status(404).json({ error: "Agent not found" });

    const updated = await prisma.agentProfile.update({
      where: { id },
      data: req.body
    });

    res.json(updated);
  }
);

export default router;
