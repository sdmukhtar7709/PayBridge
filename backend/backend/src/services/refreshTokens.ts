import { PrismaClient } from "@prisma/client";
import crypto from "crypto";

const prisma = new PrismaClient();

export async function createRefreshToken(userId: string, expiresAt: Date) {
  const token = crypto.randomBytes(48).toString("hex");
  await prisma.refreshToken.create({ data: { token, userId, expiresAt } });
  return token;
}

export async function rotateRefreshToken(token: string, newExpiresAt: Date) {
  const existing = await prisma.refreshToken.findUnique({ where: { token } });
  if (!existing || existing.revokedAt) return null;
  await prisma.refreshToken.update({
    where: { token },
    data: { revokedAt: new Date() },
  });
  const newToken = crypto.randomBytes(48).toString("hex");
  await prisma.refreshToken.create({
    data: { token: newToken, userId: existing.userId, expiresAt: newExpiresAt },
  });
  return { userId: existing.userId, token: newToken };
}

export async function revokeRefreshToken(token: string) {
  await prisma.refreshToken.updateMany({
    where: { token, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

export async function getRefreshToken(token: string) {
  return prisma.refreshToken.findUnique({ where: { token } });
}
