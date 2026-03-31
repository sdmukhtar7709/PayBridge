import { Router } from "express";
import { requireAuth } from "../middleware/auth.js";
import { validate } from "../middleware/validate.js";
import { transactionCreateSchema } from "../schemas/transactionSchemas.js";
import { createTransaction } from "../controllers/transactionController.js";
import { confirmTransactionByAgent, confirmTransactionByUser } from "../controllers/transactionController.js";
import { getTransactionStatus } from "../controllers/transactionController.js";
import { cancelTransaction } from "../controllers/transactionController.js";
import { listUserRequests } from "../controllers/transactionController.js";
import { rateAgentForTransaction } from "../controllers/transactionController.js";
import { z } from "zod";

const router = Router();

// USERS: request cash from agent by agentId, amount
router.post(
  "/request",
  requireAuth, // only a logged-in user
  validate(transactionCreateSchema),
  createTransaction // controller from previous solution
);


const confirmSchema = z.object({
  transactionId: z.string().uuid(),
  otp: z.string().length(4),
});

const rateSchema = z.object({
  rating: z.number().int().min(1).max(5),
  comment: z.string().trim().max(500).optional(),
});

router.post(
  "/confirm-user",
  requireAuth,
  validate(confirmSchema),
  confirmTransactionByUser
);

router.post(
  "/confirm-agent",
  requireAuth,
  validate(confirmSchema),
  confirmTransactionByAgent
);

router.get(
  "/request/:id/status",
  requireAuth,
  getTransactionStatus
);

router.patch(
  "/request/:id/cancel",
  requireAuth,
  cancelTransaction
);

router.get(
  "/requests",
  requireAuth,
  listUserRequests
);

router.patch(
  "/requests/:id/rate",
  requireAuth,
  validate(rateSchema),
  rateAgentForTransaction
);

export default router;