import { Router } from "express";
import prisma from "../lib/prisma.js";
import { sendOtpSms } from "../lib/sms.js";
import { sendOtpEmail } from "../lib/email.js";
import { requireAuth, AuthRequest } from "../middleware/auth.js";
import { requireRole } from "../middleware/requireRole.js";
import { validate } from "../middleware/validate.js";
import { z } from "zod";
import { Prisma, TransactionType, TransactionStatus } from "@prisma/client";

const router = Router();

/**
 * NOTE:
 * These routes are AGENT-ONLY.
 * Used for cash-in / cash-out operations handled by verified agents.
 */

const listTransactionsQuerySchema = z.object({
  accountId: z.string().uuid("accountId must be a UUID"),
  type: z.nativeEnum(TransactionType).optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  limit: z.coerce.number().int().positive().max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

const createTransactionSchema = z.object({
  accountId: z.string().uuid("accountId must be a UUID"),
  type: z.nativeEnum(TransactionType),
  amount: z.coerce.number().positive("amount must be > 0"),
  description: z.string().trim().min(1).max(500).optional(),
  occurredAt: z.string().datetime().optional(),
  toAccountId: z.string().uuid("toAccountId must be a UUID").optional(), // <-- for transfers
});

const approveSchema = z.object({
  status: z.nativeEnum(TransactionStatus),
});

const liveRequestsQuerySchema = z.object({
  limit: z.coerce.number().int().positive().max(100).default(20),
});

const historyRequestsQuerySchema = z.object({
  limit: z.coerce.number().int().positive().max(100).default(50),
});

function deriveCity(address?: string | null): string | null {
  if (!address) return null;
  const parts = address
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  if (parts.length === 0) return null;
  return parts[parts.length - 1] ?? null;
}

// 🔐 AGENT-ONLY: List live requests for this agent (includes confirmed for realtime completion)
router.get(
  "/live-requests",
  requireAuth,
  requireRole(["agent"]),
  validate(liveRequestsQuerySchema, "query"),
  async (req: AuthRequest, res) => {
    const { limit } = req.query as unknown as z.infer<typeof liveRequestsQuerySchema>;

    const agentProfile = await prisma.agentProfile.findUnique({
      where: { userId: req.user.id },
      select: { id: true },
    });

    if (!agentProfile) {
      return res.status(404).json({ error: "Agent profile not found" });
    }

    const txItems = await prisma.agentTransaction.findMany({
      where: {
        agentId: agentProfile.id,
        status: { in: ["pending", "approved", "confirmed"] },
      },
      orderBy: { createdAt: "desc" },
      take: limit,
      select: {
        id: true,
        status: true,
        amount: true,
        userId: true,
        agentId: true,
        createdAt: true,
        updatedAt: true,
        approvedAt: true,
        agentConfirmOtp: true,
        userConfirmedAt: true,
        agentConfirmedAt: true,
      },
    });

    const userIds = Array.from(new Set(txItems.map((item) => item.userId)));
    const users = await prisma.user.findMany({
      where: { id: { in: userIds } },
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        address: true,
        profileImage: true,
      },
    });

    const userMap = new Map(users.map((user) => [user.id, user]));
    const items = txItems.map((item) => {
      const user = userMap.get(item.userId);
      return {
        ...item,
        agentConfirmOtp: item.status === "approved" ? item.agentConfirmOtp : null,
        user: user
          ? {
              ...user,
              city: deriveCity(user.address),
            }
          : null,
      };
    });

    return res.json({ items });
  }
);

// 🔐 AGENT-ONLY: Delete all requests for current agent
router.delete(
  "/requests/clear-all",
  requireAuth,
  requireRole(["agent"]),
  async (req: AuthRequest, res) => {
    const agentProfile = await prisma.agentProfile.findUnique({
      where: { userId: req.user.id },
      select: { id: true },
    });

    if (!agentProfile) {
      return res.status(404).json({ error: "Agent profile not found" });
    }

    const result = await prisma.agentTransaction.deleteMany({
      where: { agentId: agentProfile.id },
    });

    return res.json({ deleted: result.count });
  }
);

// 🔐 AGENT-ONLY: Reject a pending live request assigned to current agent
router.patch(
  "/live-requests/:id/approve",
  requireAuth,
  requireRole(["agent"]),
  async (req: AuthRequest, res) => {
    const { id } = req.params;

    const agentProfile = await prisma.agentProfile.findUnique({
      where: { userId: req.user.id },
      select: { id: true },
    });

    if (!agentProfile) {
      return res.status(404).json({ error: "Agent profile not found" });
    }

    const existing = await prisma.agentTransaction.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ error: "Request not found" });
    }
    if (existing.agentId !== agentProfile.id) {
      return res.status(403).json({ error: "You are not assigned to this request" });
    }
    if (existing.status !== "pending") {
      return res.status(400).json({ error: "Only pending requests can be approved" });
    }

    const requestOtp = Math.floor(1000 + Math.random() * 9000).toString();
    const requestOtpExpiry = new Date(Date.now() + 10 * 60 * 1000);

    const updated = await prisma.agentTransaction.update({
      where: { id },
      data: {
        status: "approved",
        requestOtp,
        requestOtpExpires: requestOtpExpiry,
      },
      select: {
        id: true,
        status: true,
      },
    });

    const user = await prisma.user.findUnique({
      where: { id: existing.userId },
      select: { phone: true, email: true },
    });

    if (user?.phone) {
      try {
        await sendOtpSms(user.phone, requestOtp, updated.id);
      } catch (error) {
        console.error("Failed to send request OTP SMS:", error);
      }
    }
    if (user?.email) {
      try {
        await sendOtpEmail(user.email, requestOtp, updated.id);
      } catch (error) {
        console.error("Failed to send request OTP email:", error);
      }
    }
    return res.json(updated);
  }
);

router.post(
  "/live-requests/:id/verify-request-otp",
  requireAuth,
  requireRole(["agent"]),
  async (req: AuthRequest, res) => {
    const { id } = req.params;
    const otp = typeof req.body?.otp === "string" ? req.body.otp.trim() : "";

    const agentProfile = await prisma.agentProfile.findUnique({
      where: { userId: req.user.id },
      select: { id: true },
    });

    if (!agentProfile) {
      return res.status(404).json({ error: "Agent profile not found" });
    }

    const existing = await prisma.agentTransaction.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ error: "Request not found" });
    }
    if (existing.agentId !== agentProfile.id) {
      return res.status(403).json({ error: "You are not assigned to this request" });
    }
    if (existing.status !== "approved") {
      return res.status(400).json({ error: "Request must be approved first" });
    }
    if (!otp || otp.length !== 4) {
      return res.status(400).json({ error: "OTP required" });
    }
    if (existing.requestOtpExpires && new Date() > existing.requestOtpExpires) {
      return res.status(400).json({ error: "OTP expired" });
    }
    if (existing.requestOtp !== otp) {
      return res.status(400).json({ error: "Invalid OTP" });
    }

    const userConfirmOtp = Math.floor(1000 + Math.random() * 9000).toString();
    const agentConfirmOtp = Math.floor(1000 + Math.random() * 9000).toString();
    const confirmExpiry = new Date(Date.now() + 10 * 60 * 1000);

    const updated = await prisma.agentTransaction.update({
      where: { id },
      data: {
        approvedAt: new Date(),
        userConfirmOtp,
        agentConfirmOtp,
        confirmOtpExpires: confirmExpiry,
      },
      select: {
        id: true,
        status: true,
        approvedAt: true,
        agentConfirmOtp: true,
      },
    });

    const user = await prisma.user.findUnique({
      where: { id: existing.userId },
      select: { phone: true, email: true },
    });

    if (user?.phone) {
      try {
        await sendOtpSms(user.phone, userConfirmOtp, updated.id);
      } catch (error) {
        console.error("Failed to send user OTP SMS:", error);
      }
    }
    if (user?.email) {
      try {
        await sendOtpEmail(user.email, userConfirmOtp, updated.id);
      } catch (error) {
        console.error("Failed to send user OTP email:", error);
      }
    }

    return res.json(updated);
  }
);

router.patch(
  "/live-requests/:id/reject",
  requireAuth,
  requireRole(["agent"]),
  async (req: AuthRequest, res) => {
    const { id } = req.params;

    const agentProfile = await prisma.agentProfile.findUnique({
      where: { userId: req.user.id },
      select: { id: true },
    });

    if (!agentProfile) {
      return res.status(404).json({ error: "Agent profile not found" });
    }

    const existing = await prisma.agentTransaction.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ error: "Request not found" });
    }
    if (existing.agentId !== agentProfile.id) {
      return res.status(403).json({ error: "You are not assigned to this request" });
    }
    if (existing.status !== "pending") {
      return res.status(400).json({ error: "Only pending requests can be rejected" });
    }

    const updated = await prisma.agentTransaction.update({
      where: { id },
      data: { status: "rejected" },
    });

    return res.json({ id: updated.id, status: updated.status });
  }
);

// 🔐 AGENT-ONLY: Archive an approved live request (hide from agent panel)
router.patch(
  "/live-requests/:id/archive",
  requireAuth,
  requireRole(["agent"]),
  async (req: AuthRequest, res) => {
    const { id } = req.params;

    const agentProfile = await prisma.agentProfile.findUnique({
      where: { userId: req.user.id },
      select: { id: true },
    });

    if (!agentProfile) {
      return res.status(404).json({ error: "Agent profile not found" });
    }

    const existing = await prisma.agentTransaction.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ error: "Request not found" });
    }
    if (existing.agentId !== agentProfile.id) {
      return res.status(403).json({ error: "You are not assigned to this request" });
    }
    if (existing.status === "archived") {
      return res.json({ id: existing.id, status: existing.status });
    }
    if (existing.status !== "approved") {
      return res.status(400).json({ error: "Only approved requests can be archived" });
    }

    const updated = await prisma.agentTransaction.update({
      where: { id },
      data: { status: "archived" },
      select: { id: true, status: true },
    });

    return res.json(updated);
  }
);

// 🔐 AGENT-ONLY: List transaction history for current agent
router.get(
  "/history",
  requireAuth,
  requireRole(["agent"]),
  validate(historyRequestsQuerySchema, "query"),
  async (req: AuthRequest, res) => {
    const { limit } = req.query as unknown as z.infer<typeof historyRequestsQuerySchema>;

    const agentProfile = await prisma.agentProfile.findUnique({
      where: { userId: req.user.id },
      select: { id: true },
    });

    if (!agentProfile) {
      return res.status(404).json({ error: "Agent profile not found" });
    }

    const txItems = await prisma.agentTransaction.findMany({
      where: {
        agentId: agentProfile.id,
        status: { in: ["approved", "confirmed", "rejected", "cancelled"] },
      },
      orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
      take: limit,
    });

    const userIds = Array.from(new Set(txItems.map((item) => item.userId)));
    const users = await prisma.user.findMany({
      where: { id: { in: userIds } },
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        address: true,
      },
    });

    const userMap = new Map(users.map((user) => [user.id, user]));
    const items = txItems.map((item) => {
      const user = userMap.get(item.userId);
      return {
        ...item,
        user: user
          ? {
              ...user,
              city: deriveCity(user.address),
            }
          : null,
      };
    });

    return res.json({ items });
  }
);

// 🔐 AGENT-ONLY: List handled transactions
router.get(
  "/",
  requireAuth,
  requireRole(["agent"]),
  validate(listTransactionsQuerySchema, "query"),
  async (req: AuthRequest, res) => {
    const { accountId, type, from, to, limit, offset } =
      req.query as unknown as z.infer<typeof listTransactionsQuerySchema>;

    const where: any = { accountId };
    if (type) where.type = type;
    if (from) where.occurredAt = { ...(where.occurredAt || {}), gte: new Date(from) };
    if (to) where.occurredAt = { ...(where.occurredAt || {}), lte: new Date(to) };

    const [items, total] = await Promise.all([
      prisma.transaction.findMany({
        where,
        orderBy: { occurredAt: "desc" },
        take: limit,
        skip: offset,
      }),
      prisma.transaction.count({ where }),
    ]);

    res.json({ total, items });
  }
);

// 🔐 AGENT-ONLY: Create transaction (cash in / cash out / transfer)
router.post(
  "/",
  requireAuth,
  requireRole(["agent"]),
  validate(createTransactionSchema, "body"),
  async (req: AuthRequest, res) => {
    const { accountId, type, amount, description, occurredAt, toAccountId } =
      req.body as z.infer<typeof createTransactionSchema>;

    const tx = await prisma.transaction.create({
      data: {
        accountId,
        type,
        amount: new Prisma.Decimal(amount),
        description,
        occurredAt: occurredAt ? new Date(occurredAt) : new Date(),
        status: TransactionStatus.PENDING,
        toAccountId: type === TransactionType.TRANSFER ? toAccountId : null,
      },
    });

    res.status(201).json(tx);
  }
);

// 🔐 AGENT-ONLY: Approve or reject a transaction; reflect on balances!
router.patch(
  "/:id/status",
  requireAuth,
  requireRole(["agent"]),
  validate(approveSchema, "body"),
  async (req: AuthRequest, res) => {
    const { id } = req.params;
    const { status } = req.body as z.infer<typeof approveSchema>;

    const tx = await prisma.transaction.findUnique({ where: { id } });
    if (!tx) return res.status(404).json({ error: "Transaction not found" });
    if (tx.status !== TransactionStatus.PENDING) {
      return res.status(400).json({ error: "Only PENDING transactions can be updated" });
    }

    let updated;

    if (status === TransactionStatus.APPROVED) {
      // Approve logic, update balances atomically
      updated = await prisma.$transaction(async (p) => {
        // TRANSFER: move money between accounts
        if (tx.type === TransactionType.TRANSFER) {
          // Precondition: Both accounts exist, enough funds
          const fromAccount = await p.account.findUnique({
            where: { id: tx.accountId },
            select: { balance: true },
          });
          if (!fromAccount) throw new Error("Source account not found");
          if (fromAccount.balance.lessThan(tx.amount)) {
            throw new Error("Insufficient funds in source account");
          }
          // Subtract from source
          await p.account.update({
            where: { id: tx.accountId },
            data: { balance: { decrement: Number(tx.amount) } },
          });
          // Add to destination if set
          if (tx.toAccountId) {
            await p.account.update({
              where: { id: tx.toAccountId },
              data: { balance: { increment: Number(tx.amount) } },
            });
          }
        }
        // EXPENSE: subtract
        else if (tx.type === TransactionType.EXPENSE) {
          await p.account.update({
            where: { id: tx.accountId },
            data: { balance: { decrement: Number(tx.amount) } },
          });
        }
        // INCOME: add
        else if (tx.type === TransactionType.INCOME) {
          await p.account.update({
            where: { id: tx.accountId },
            data: { balance: { increment: Number(tx.amount) } },
          });
        }
        // Update transaction status
        const txn = await p.transaction.update({
          where: { id },
          data: { status },
        });
        return txn;
      });
    } else {
      // For REJECTED: just update status
      updated = await prisma.transaction.update({
        where: { id },
        data: { status },
      });
    }

    res.json(updated);
  }
);

export default router;