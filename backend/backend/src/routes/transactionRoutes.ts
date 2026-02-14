import { Router } from "express";
import prisma from "../lib/prisma.js";
import { requireAuth, AuthRequest } from "../middleware/auth.js";
import { validate } from "../middleware/validate.js";
import { z } from "zod";
import { Prisma, TransactionType } from "@prisma/client";

const router = Router();

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
  categoryId: z.string().uuid().optional(),
  occurredAt: z.string().datetime().optional(),
});

const transferSchema = z.object({
  fromAccountId: z.string().uuid(),
  toAccountId: z.string().uuid(),
  amount: z.coerce.number().positive("amount must be > 0"),
  description: z.string().trim().min(1).max(500).optional(),
  occurredAt: z.string().datetime().optional(),
});

// List transactions with filters
router.get("/", requireAuth, validate(listTransactionsQuerySchema, "query"), async (req: AuthRequest, res) => {
  const { accountId, type, from, to, limit, offset } = req.query as unknown as z.infer<typeof listTransactionsQuerySchema>;

  const account = await prisma.account.findFirst({
    where: { id: accountId, userId: req.user!.id },
  });
  if (!account) return res.status(404).json({ error: "Account not found" });

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
});

// Create transaction
router.post("/", requireAuth, validate(createTransactionSchema, "body"), async (req: AuthRequest, res) => {
  const { accountId, type, amount, description, categoryId, occurredAt } = req.body as z.infer<typeof createTransactionSchema>;

  const account = await prisma.account.findFirst({
    where: { id: accountId, userId: req.user!.id },
  });
  if (!account) return res.status(404).json({ error: "Account not found" });

  if (categoryId) {
    const category = await prisma.category.findFirst({
      where: { id: categoryId, userId: req.user!.id },
    });
    if (!category) return res.status(400).json({ error: "Invalid categoryId" });
  }

  const tx = await prisma.transaction.create({
    data: {
      accountId,
      type,
      amount,
      description,
      categoryId: categoryId || null,
      occurredAt: occurredAt ? new Date(occurredAt) : new Date(),
    },
  });

  res.status(201).json(tx);
});

// Transfer between two user-owned accounts
router.post("/transfer", requireAuth, validate(transferSchema, "body"), async (req: AuthRequest, res) => {
  const { fromAccountId, toAccountId, amount, description, occurredAt } = req.body as z.infer<typeof transferSchema>;

  if (fromAccountId === toAccountId) {
    return res.status(400).json({ error: "fromAccountId and toAccountId must differ" });
  }

  const [fromAccount, toAccount] = await Promise.all([
    prisma.account.findFirst({ where: { id: fromAccountId, userId: req.user!.id } }),
    prisma.account.findFirst({ where: { id: toAccountId, userId: req.user!.id } }),
  ]);

  if (!fromAccount || !toAccount) {
    return res.status(404).json({ error: "Account not found or not owned" });
  }

  const amountDec = new Prisma.Decimal(amount);
  if (fromAccount.balance.lt(amountDec)) {
    return res.status(400).json({ error: "Insufficient funds" });
  }

  const occurred = occurredAt ? new Date(occurredAt) : new Date();

  const result = await prisma.$transaction(async (tx) => {
    await tx.account.update({
      where: { id: fromAccountId },
      data: { balance: { decrement: amountDec } },
    });
    await tx.account.update({
      where: { id: toAccountId },
      data: { balance: { increment: amountDec } },
    });

    const debit = await tx.transaction.create({
      data: {
        accountId: fromAccountId,
        type: TransactionType.TRANSFER,
        amount: amountDec,
        description: description ?? "Transfer out",
        categoryId: null,
        occurredAt: occurred,
      },
    });

    const credit = await tx.transaction.create({
      data: {
        accountId: toAccountId,
        type: TransactionType.TRANSFER,
        amount: amountDec,
        description: description ?? "Transfer in",
        categoryId: null,
        occurredAt: occurred,
      },
    });

    return { debit, credit };
  });

  res.status(201).json(result);
});

export default router;
