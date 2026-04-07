import prisma from "../lib/prisma.js";
import { Request, Response } from "express";
import { AuthRequest } from "../middleware/auth.js";

type AgentModerationStatus = "pending" | "verified" | "unverified" | "banned";

function resolveAgentStatus(agent: {
  status?: string | null;
  isBanned: boolean;
  isVerified: boolean;
}): AgentModerationStatus {
  const status = (agent.status ?? "").trim().toLowerCase();
  if (
    status === "pending" ||
    status === "verified" ||
    status === "unverified" ||
    status === "banned"
  ) {
    return status;
  }
  if (agent.isBanned) return "banned";
  if (agent.isVerified) return "verified";
  return "pending";
}

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
 * User requests cash from an agent. OTP is generated only after agent approval.
 */
export async function createTransaction(req: Request, res: Response) {
  const { agentId, amount } = req.body;
  const userId = req.user.id; // <-- Assumes requireAuth middleware sets req.user
  const numericAmount = Number(amount);

  if (!Number.isFinite(numericAmount) || !Number.isInteger(numericAmount)) {
    return res.status(400).json({ error: "Amount must be a valid integer" });
  }

  const normalizedAmount = Math.max(0, numericAmount);
  const agentCommission = normalizedAmount >= 1000 ? Math.round(normalizedAmount * 0.005) : 0;
  const totalPaid = normalizedAmount + agentCommission;
  const agentReceived = totalPaid;

  // Ensure target agent profile exists and is not banned.
  // Accept either AgentProfile.id (preferred) or legacy userId input.
  const agent = await prisma.agentProfile.findFirst({
    where: {
      OR: [{ id: agentId }, { userId: agentId }],
    },
    select: {
      id: true,
      status: true,
      isBanned: true,
      isVerified: true,
      available: true,
    },
  });
  if (!agent) {
    return res.status(400).json({ error: "Agent not available" });
  }
  const agentStatus = resolveAgentStatus(agent);
  if (agentStatus === "banned") {
    return res.status(400).json({ error: "Agent not available" });
  }
  if (agentStatus !== "verified") {
    return res.status(400).json({
      error: "Agent is not verified. Please try another or use nearby ATM and banks map feature on our app.",
    });
  }
  if (!agent.available) {
    return res.status(400).json({ error: "Agent is offline" });
  }

  const txn = await prisma.agentTransaction.create({
    data: {
      status: "pending",
      amount: normalizedAmount,
      agentCommission,
      totalPaid,
      agentReceived,
      userId,
      agentId: agent.id,
      requestOtp: "",
      requestOtpExpires: null,
    }
  });

  res.json({
    id: txn.id,
    status: txn.status,
    amount: txn.amount,
    agentCommission: txn.agentCommission,
    totalPaid: txn.totalPaid,
    agentReceived: txn.agentReceived,
    otp: "PENDING" // OTP is generated after agent approval
  });
}

/**
 * POST /transactions/confirm-user
 * User confirms transaction by entering AGENT OTP.
 */
export async function confirmTransactionByUser(req: AuthRequest, res: Response) {
  const { transactionId, otp } = req.body;

  const txn = await prisma.agentTransaction.findUnique({
    where: { id: transactionId },
    select: {
      id: true,
      status: true,
      userId: true,
      agentId: true,
      agentConfirmOtp: true,
      userConfirmedAt: true,
      agentConfirmedAt: true,
      confirmOtpExpires: true,
    },
  });

  if (!txn) return res.status(404).json({ error: "Transaction not found" });
  if (txn.userId !== req.user.id) {
    return res.status(403).json({ error: "You are not assigned to this request" });
  }
  if (txn.status !== "approved") {
    return res.status(400).json({ error: "Transaction is not approved yet" });
  }
  if (txn.confirmOtpExpires && new Date() > txn.confirmOtpExpires) {
    return res.status(400).json({ error: "OTP expired" });
  }
  if (!txn.agentConfirmOtp || txn.agentConfirmOtp !== otp) {
    return res.status(400).json({ error: "Invalid OTP" });
  }

  const updated = await prisma.agentTransaction.update({
    where: { id: transactionId },
    data: {
      userConfirmedAt: txn.userConfirmedAt ?? new Date(),
      status: txn.agentConfirmedAt ? "confirmed" : txn.status,
      completedAt: txn.agentConfirmedAt ? new Date() : null,
    },
  });

  return res.json({
    id: updated.id,
    status: updated.status,
    completedAt: updated.completedAt,
  });
}

/**
 * POST /transactions/confirm-agent
 * Agent confirms transaction by entering USER OTP.
 */
export async function confirmTransactionByAgent(req: AuthRequest, res: Response) {
  const { transactionId, otp } = req.body;

  const txn = await prisma.agentTransaction.findUnique({
    where: { id: transactionId },
    select: {
      id: true,
      status: true,
      userId: true,
      agentId: true,
      userConfirmOtp: true,
      userConfirmedAt: true,
      agentConfirmedAt: true,
      confirmOtpExpires: true,
    },
  });

  if (!txn) return res.status(404).json({ error: "Transaction not found" });
  if (txn.status !== "approved") {
    return res.status(400).json({ error: "Transaction is not approved yet" });
  }

  const agentProfile = await prisma.agentProfile.findUnique({
    where: { userId: req.user.id },
    select: { id: true, status: true, isBanned: true, isVerified: true },
  });

  const agentStatus = agentProfile ? resolveAgentStatus(agentProfile) : "pending";

  if (!agentProfile || txn.agentId !== agentProfile.id) {
    return res.status(403).json({ error: "You are not the assigned agent" });
  }
  if (agentStatus === "banned") {
    return res.status(403).json({ error: "Agent is banned" });
  }
  if (agentStatus !== "verified") {
    return res.status(403).json({ error: "Agent is not verified" });
  }
  if (txn.confirmOtpExpires && new Date() > txn.confirmOtpExpires) {
    return res.status(400).json({ error: "OTP expired" });
  }
  if (!txn.userConfirmOtp || txn.userConfirmOtp !== otp) {
    return res.status(400).json({ error: "Invalid OTP" });
  }

  const updated = await prisma.agentTransaction.update({
    where: { id: transactionId },
    data: {
      agentConfirmedAt: txn.agentConfirmedAt ?? new Date(),
      status: txn.userConfirmedAt ? "confirmed" : txn.status,
      completedAt: txn.userConfirmedAt ? new Date() : null,
    },
  });

  return res.json({
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
      agentCommission: true,
      totalPaid: true,
      agentReceived: true,
      requestOtp: true,
      userConfirmOtp: true,
      approvedAt: true,
      agentConfirmedAt: true,
      userConfirmedAt: true,
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
    requestOtp: txn.status === "approved" || txn.status === "confirmed" ? txn.requestOtp : null,
    userConfirmOtp: txn.status === "approved" || txn.status === "confirmed" ? txn.userConfirmOtp : null,
    approvedAt: txn.approvedAt,
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

  const where: any = { userId: req.user.id };
  if (status) {
    where.status = status;
  } else {
    where.status = { not: "archived" };
  }

  const items = await prisma.agentTransaction.findMany({
    where,
    orderBy: { createdAt: "desc" },
    take: limit,
    select: {
      id: true,
      status: true,
      requestOtp: true,
      userConfirmOtp: true,
      userRating: true,
      ratedAt: true,
      approvedAt: true,
      userConfirmedAt: true,
      agentConfirmedAt: true,
      amount: true,
      agentCommission: true,
      totalPaid: true,
      agentReceived: true,
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
      latitude: true,
      longitude: true,
      ratingSum: true,
      ratingCount: true,
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
    requestOtp: item.status === "approved" || item.status === "confirmed" ? item.requestOtp : null,
    userConfirmOtp:
      item.status === "approved" || item.status === "confirmed" ? item.userConfirmOtp : null,
    approvedAt: item.approvedAt,
    agent: agentMap.get(item.agentId) ?? null,
  }));

  return res.json({ items: enriched });
}

/**
 * PATCH /transactions/requests/:id/rate
 * User rates assigned agent once, only after confirmed completion.
 */
export async function rateAgentForTransaction(req: AuthRequest, res: Response) {
  const { id } = req.params;
  const rating = Number(req.body?.rating);
  const comment = typeof req.body?.comment === "string" ? req.body.comment.trim() : "";

  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    return res.status(400).json({ error: "Rating must be an integer between 1 and 5" });
  }

  const txn = await prisma.agentTransaction.findUnique({
    where: { id },
    select: {
      id: true,
      status: true,
      userId: true,
      agentId: true,
      userRating: true,
    },
  });

  if (!txn) {
    return res.status(404).json({ error: "Transaction not found" });
  }
  if (txn.userId !== req.user.id) {
    return res.status(403).json({ error: "You are not allowed to rate this transaction" });
  }
  if (txn.status !== "confirmed") {
    return res.status(400).json({ error: "You can rate only after completed transaction" });
  }
  if (txn.userRating !== null) {
    return res.status(409).json({ error: "This transaction has already been rated" });
  }

  const now = new Date();
  const updatedAgent = await prisma.$transaction(async (tx) => {
    await tx.agentTransaction.update({
      where: { id: txn.id },
      data: {
        userRating: rating,
        userRatingComment: comment || null,
        ratedAt: now,
      },
    });

    return tx.agentProfile.update({
      where: { id: txn.agentId },
      data: {
        ratingSum: { increment: rating },
        ratingCount: { increment: 1 },
      },
      select: {
        ratingSum: true,
        ratingCount: true,
      },
    });
  });

  const averageRating =
    updatedAgent.ratingCount > 0 ? updatedAgent.ratingSum / updatedAgent.ratingCount : null;

  return res.json({
    id: txn.id,
    agentId: txn.agentId,
    rating,
    comment: comment || null,
    ratedAt: now.toISOString(),
    agentRatingAverage: averageRating,
    agentRatingCount: updatedAgent.ratingCount,
  });
}

/**
 * DELETE /transactions/requests/clear-all
 * User deletes all own requests.
 */
export async function clearAllUserRequests(req: AuthRequest, res: Response) {
  const result = await prisma.agentTransaction.deleteMany({
    where: { userId: req.user.id },
  });

  return res.json({ deleted: result.count });
}

/**
 * PATCH /transactions/requests/:id/archive
 * User archives own request (removes from default list).
 */
export async function archiveUserRequest(req: AuthRequest, res: Response) {
  const { id } = req.params;

  const txn = await prisma.agentTransaction.findUnique({
    where: { id },
    select: { id: true, status: true, userId: true },
  });

  if (!txn) {
    return res.status(404).json({ error: "Transaction not found" });
  }
  if (txn.userId !== req.user.id) {
    return res.status(403).json({ error: "You are not allowed to archive this request" });
  }
  if (txn.status === "pending") {
    return res.status(400).json({ error: "Pending request cannot be archived" });
  }
  if (txn.status === "archived") {
    return res.json({ id: txn.id, status: txn.status });
  }

  const updated = await prisma.agentTransaction.update({
    where: { id },
    data: { status: "archived" },
    select: { id: true, status: true },
  });

  return res.json(updated);
}