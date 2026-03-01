import prisma from "../lib/prisma.js";
import { Request, Response } from "express";
import { AuthRequest } from "../middleware/auth.js";
import { sendOtpSms } from "../lib/sms.js"; // Make sure you have this utility!
import { sendOtpEmail } from "../lib/email.js";

// Extend Express Request interface to include 'user'
declare global {
  namespace Express {
    interface User {
      id: string;
      // add other user properties if needed
    }
    interface Request {
      user: User;
    }
  }
}

/**
 * POST /transactions/request
 * User requests cash from an agent. Generates OTP with expiry, sends SMS if phone present.
 */
export async function createTransaction(req: Request, res: Response) {
  const { agentId, amount } = req.body;
  const userId = req.user.id; // <-- Assumes requireAuth middleware sets req.user

  // Ensure target agent profile exists and is not banned.
  // Accept either AgentProfile.id (preferred) or legacy userId input.
  const agent = await prisma.agentProfile.findFirst({
    where: {
      isBanned: false,
      OR: [{ id: agentId }, { userId: agentId }],
    },
  });
  if (!agent) {
    return res.status(400).json({ error: "Agent not available" });
  }

  // Generate 4-digit OTP and expiry (10 minutes)
  const otp = Math.floor(1000 + Math.random() * 9000).toString();
  const otpExpiry = new Date(Date.now() + 10 * 60 * 1000); // 10 min from now

  const txn = await prisma.agentTransaction.create({
    data: {
      status: "pending",
      amount,
      userId,
      agentId: agent.id,
      otp,
      otpExpires: otpExpiry,
    }
  });

  // Find user with phone number for SMS
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { phone: true, email: true }
  });
  if (user && user.phone) {
    try {
      await sendOtpSms(user.phone, otp, txn.id);
    } catch (err) {
      // Log SMS error, do not fail transaction for user
      console.error("Failed to send OTP SMS:", err);
    }
  }
  if (user && user.email) {
    await sendOtpEmail(user.email, otp, txn.id);
  }
  // Log OTP for server-side debugging (never send real OTP to client!)
  console.log(`OTP for transaction ${txn.id}: ${otp} (expires ${otpExpiry.toISOString()})`);

  res.json({
    id: txn.id,
    status: txn.status,
    otp: "SENT" // Never send real OTP to client!
  });
}

/**
 * POST /transactions/confirm
 * Agent (or user) confirms transaction by OTP.
 */
export async function confirmTransaction(req: AuthRequest, res: Response) {
  const { transactionId, otp } = req.body;

  // Find the transaction
  const txn = await prisma.agentTransaction.findUnique({
    where: { id: transactionId },
    select: {
      id: true,
      status: true,
      amount: true,
      userId: true,
      agentId: true,
      otp: true,
      completedAt: true,
      otpExpires: true // Ensure otpExpires is selected
    }
  });
  if (!txn) return res.status(404).json({ error: "Transaction not found" });
  if (txn.status !== "pending" && txn.status !== "approved") {
    return res.status(400).json({ error: "Transaction already completed or cancelled" });
  }
  if (txn.otpExpires && new Date() > txn.otpExpires) return res.status(400).json({ error: "OTP expired" });

  // AGENT MUST MATCH by AgentProfile.id
  const agentProfile = await prisma.agentProfile.findUnique({
    where: { userId: req.user.id },
    select: { id: true },
  });

  if (!agentProfile || txn.agentId !== agentProfile.id) {
    return res.status(403).json({ error: "You are not the assigned agent" });
  }

  if (txn.otp !== otp) return res.status(400).json({ error: "Invalid OTP" });

  // TODO: Move funds here (decrement agent's cash limit if needed, increment user's balance etc.)

  // Mark transaction as completed
  const updated = await prisma.agentTransaction.update({
    where: { id: transactionId },
    data: {
      status: "confirmed",
      completedAt: new Date(),
    }
  });

  res.json({
    id: updated.id,
    status: updated.status,
    completedAt: updated.completedAt,
  });
}

/**
 * GET /transactions/request/:id/status
 * User checks latest status of own request.
 */
export async function getTransactionStatus(req: AuthRequest, res: Response) {
  const { id } = req.params;

  const txn = await prisma.agentTransaction.findUnique({
    where: { id },
    select: {
      id: true,
      status: true,
      amount: true,
      otp: true,
      userId: true,
      agentId: true,
      createdAt: true,
      updatedAt: true,
    },
  });

  if (!txn) {
    return res.status(404).json({ error: "Transaction not found" });
  }
  if (txn.userId !== req.user.id) {
    return res.status(403).json({ error: "You are not allowed to view this request" });
  }

  const agent = await prisma.agentProfile.findUnique({
    where: { id: txn.agentId },
    select: {
      id: true,
      city: true,
      locationName: true,
      user: {
        select: {
          name: true,
          phone: true,
          email: true,
        },
      },
    },
  });

  return res.json({
    ...txn,
    otp: txn.status === "approved" || txn.status === "confirmed" ? txn.otp : null,
    agent,
  });
}

/**
 * PATCH /transactions/request/:id/cancel
 * User cancels own pending request.
 */
export async function cancelTransaction(req: AuthRequest, res: Response) {
  const { id } = req.params;

  const txn = await prisma.agentTransaction.findUnique({
    where: { id },
    select: { id: true, status: true, userId: true },
  });

  if (!txn) {
    return res.status(404).json({ error: "Transaction not found" });
  }
  if (txn.userId !== req.user.id) {
    return res.status(403).json({ error: "You are not allowed to cancel this request" });
  }
  if (txn.status !== "pending") {
    return res.status(400).json({ error: "Only pending request can be cancelled" });
  }

  const updated = await prisma.agentTransaction.update({
    where: { id },
    data: { status: "cancelled" },
  });

  return res.json({ id: updated.id, status: updated.status });
}

/**
 * GET /transactions/requests
 * User sees all own raised requests with status and agent info.
 */
export async function listUserRequests(req: AuthRequest, res: Response) {
  const limitRaw = Number(req.query.limit ?? 50);
  const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 200) : 50;
  const status = typeof req.query.status === "string" ? req.query.status.trim().toLowerCase() : "";

  const where: { userId: string; status?: string } = { userId: req.user.id };
  if (status) {
    where.status = status;
  }

  const items = await prisma.agentTransaction.findMany({
    where,
    orderBy: { createdAt: "desc" },
    take: limit,
    select: {
      id: true,
      status: true,
      otp: true,
      amount: true,
      createdAt: true,
      updatedAt: true,
      agentId: true,
      completedAt: true,
    },
  });

  const agentIds = Array.from(new Set(items.map((item) => item.agentId)));
  const profiles = await prisma.agentProfile.findMany({
    where: { id: { in: agentIds } },
    select: {
      id: true,
      city: true,
      locationName: true,
      user: {
        select: {
          id: true,
          name: true,
          phone: true,
          email: true,
          address: true,
        },
      },
    },
  });

  const agentMap = new Map(profiles.map((profile) => [profile.id, profile]));

  const enriched = items.map((item) => ({
    ...item,
    otp: item.status === "approved" || item.status === "confirmed" ? item.otp : null,
    agent: agentMap.get(item.agentId) ?? null,
  }));

  return res.json({ items: enriched });
}