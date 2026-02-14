import { Router } from "express";
import prisma from "../lib/prisma.js";
import { requireAuth, AuthRequest } from "../middleware/auth.js";
import { z } from "zod";
import { validate } from "../middleware/validate.js";

const router = Router();

const createAccountSchema = z.object({
  name: z.string().trim().min(1, "name is required"),
  balance: z.coerce.number(),
});

// List accounts for current user
router.get("/", requireAuth, async (req: AuthRequest, res) => {
  const accounts = await prisma.account.findMany({
    where: { userId: req.user!.id },
    orderBy: { createdAt: "desc" },
  });
  res.json(accounts);
});

// Create account
router.post("/", requireAuth, validate(createAccountSchema, "body"), async (req: AuthRequest, res) => {
  const { name, balance } = req.body as z.infer<typeof createAccountSchema>;
  const account = await prisma.account.create({
    data: {
      name,
      balance,
      userId: req.user!.id,
    },
  });
  res.status(201).json(account);
});

// Get one account (owned)
router.get("/:id", requireAuth, async (req: AuthRequest, res) => {
  const account = await prisma.account.findFirst({
    where: { id: req.params.id, userId: req.user!.id },
  });
  if (!account) return res.status(404).json({ error: "Not found" });
  res.json(account);
});

export default router;
