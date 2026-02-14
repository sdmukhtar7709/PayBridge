import { Router } from "express";
import prisma from "../lib/prisma.js";
import bcrypt from "bcrypt";

const router = Router();

router.post("/register-agent", async (req, res) => {
  const { email, password, name, locationName, cashLimit } = req.body;
  if (!email || !password || !name || !locationName || !cashLimit) {
    return res.status(400).json({ error: "Missing fields" });
  }
  const existingUser = await prisma.user.findUnique({ where: { email } });
  if (existingUser) return res.status(409).json({ error: "Email already registered" });

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await prisma.user.create({
    data: {
      email,
      passwordHash,
      name,
      role: "agent", // assign "agent" role directly
    },
  });

  const agentProfile = await prisma.agentProfile.create({
    data: {
      userId: user.id,
      locationName,
      cashLimit,
      isVerified: true, // or false if you want manual approval
      isBanned: false,
    },
  });

  res.json({ user: { id: user.id, email: user.email }, agentProfile });
});

export default router;
