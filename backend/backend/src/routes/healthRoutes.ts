import { Router } from "express";
import prisma from "../lib/prisma.js";

const router = Router();

router.get("/health", async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({ ok: true, db: "up" });
  } catch (err) {
    console.error("DB health check failed:", err);
    res.status(500).json({ ok: false, db: "down" });
  }
});

export default router;
