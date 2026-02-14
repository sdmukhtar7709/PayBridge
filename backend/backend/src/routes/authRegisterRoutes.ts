import { Router } from "express";
import prisma from "../lib/prisma.js";
import bcrypt from "bcrypt";
import { z } from "zod";

const router = Router();

const registerSchema = z.object({
  name: z.string().min(1, "Name required"),
  email: z.string().email("Invalid email"),
  password: z.string().min(6, "Password must be at least 6 chars"),
});

router.post("/auth/register", async (req, res) => {
  // Validate request body
  const result = registerSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(400).json({ error: result.error.errors[0].message });
  }
  const { name, email, password } = result.data;

  // Check if email exists
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    return res.status(409).json({ error: "Email already registered" });
  }

  // Hash password
  const passwordHash = await bcrypt.hash(password, 10);

  // Create user
  const user = await prisma.user.create({
    data: {
      name,
      email,
      passwordHash,
      role: "user",
    },
    select: { id: true, name: true, email: true, role: true },
  });

  res.status(201).json({ user });
});

export default router;