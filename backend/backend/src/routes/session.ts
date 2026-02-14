import { Router } from "express";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { PrismaClient } from "@prisma/client";
import { env } from "../config/env.js";
import { createRefreshToken, rotateRefreshToken, revokeRefreshToken, getRefreshToken } from "../services/refreshTokens.js";

const prisma = new PrismaClient();
const router = Router();

function signAccessToken(payload: any) {
  return jwt.sign(payload, env.JWT_SECRET, { expiresIn: "15m" });
}

router.post("/login-with-refresh", async (req, res, next) => {
  try {
    const { email, password } = req.body ?? {};
    if (!email || !password) {
      return res.status(400).json({ error: { code: "VALIDATION_ERROR", message: "Email and password required" } });
    }

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      return res.status(401).json({ error: { code: "INVALID_CREDENTIALS", message: "Invalid credentials" } });
    }

    const ok = await bcrypt.compare(password, (user as any).passwordHash ?? "");
    if (!ok) {
      return res.status(401).json({ error: { code: "INVALID_CREDENTIALS", message: "Invalid credentials" } });
    }

    const accessToken = signAccessToken({ userId: user.id, role: (user as any).role ?? "user" });
    const refreshToken = await createRefreshToken(
      user.id,
      new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30d
    );

    res.json({ accessToken, refreshToken });
  } catch (err) {
    next(err);
  }
});

router.post("/refresh", async (req, res, next) => {
  try {
    const { refreshToken } = req.body ?? {};
    if (!refreshToken) {
      return res.status(400).json({ error: { code: "VALIDATION_ERROR", message: "refreshToken required" } });
    }

    const stored = await getRefreshToken(refreshToken);
    if (!stored || stored.revokedAt || stored.expiresAt < new Date()) {
      return res.status(401).json({ error: { code: "INVALID_REFRESH", message: "Invalid refresh token" } });
    }

    const rotated = await rotateRefreshToken(refreshToken, new Date(Date.now() + 30 * 24 * 60 * 60 * 1000));
    if (!rotated) {
      return res.status(401).json({ error: { code: "INVALID_REFRESH", message: "Invalid refresh token" } });
    }

    const user = await prisma.user.findUnique({ where: { id: rotated.userId } });
    if (!user) {
      return res.status(401).json({ error: { code: "INVALID_REFRESH", message: "Invalid refresh token" } });
    }

    const accessToken = signAccessToken({ userId: user.id, role: (user as any).role ?? "user" });
    res.json({ accessToken, refreshToken: rotated.token });
  } catch (err) {
    next(err);
  }
});

router.post("/logout", async (req, res, next) => {
  try {
    const { refreshToken } = req.body ?? {};
    if (refreshToken) {
      await revokeRefreshToken(refreshToken);
    }
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

export default router;
