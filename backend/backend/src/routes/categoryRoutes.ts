import { Router } from "express";
import prisma from "../lib/prisma.js";
import { requireAuth, AuthRequest } from "../middleware/auth.js";
import { z } from "zod";
import { validate } from "../middleware/validate.js";
import { TransactionType } from "@prisma/client";

const router = Router();

const createCategorySchema = z.object({
  name: z.string().trim().min(1, "name is required").max(100),
  type: z.nativeEnum(TransactionType),
});

// List categories for current user
router.get("/", requireAuth, async (req: AuthRequest, res) => {
  const categories = await prisma.category.findMany({
    where: { userId: req.user!.id },
    orderBy: [{ type: "asc" }, { name: "asc" }],
  });
  res.json(categories);
});

// Create category
router.post("/", requireAuth, validate(createCategorySchema, "body"), async (req: AuthRequest, res) => {
  const { name, type } = req.body as z.infer<typeof createCategorySchema>;

  const category = await prisma.category.create({
    data: { name, type, userId: req.user!.id },
  });

  res.status(201).json(category);
});

export default router;
