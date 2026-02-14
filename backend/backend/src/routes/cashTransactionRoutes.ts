import { Router } from "express";
import { requireAuth } from "../middleware/auth.js";
import { validate } from "../middleware/validate.js";
import { transactionCreateSchema } from "../schemas/transactionSchemas.js";
import { createTransaction } from "../controllers/transactionController.js";
import { confirmTransaction } from "../controllers/transactionController.js";
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
  otp: z.string().length(6)
});

router.post(
  "/confirm",
  requireAuth,
  validate(confirmSchema),
  confirmTransaction
);

export default router;