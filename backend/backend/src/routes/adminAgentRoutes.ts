import { Router } from "express";
import { requireAuth } from "../middleware/auth.js";
import {
  adminAgentUpdateSchema,
  adminReportsQuerySchema,
  adminTransactionsQuerySchema,
} from "../schemas/adminAgentSchemas.js";
import { validate } from "../middleware/validate.js";
import { requireRole } from "../middleware/requireRole.js";
import {
  adminBanAgent,
  adminGetTransaction,
  adminGetReports,
  adminListAgents,
  adminListTransactions,
  adminUnbanAgent,
  adminUnverifyAgent,
  adminUpdateAgent,
  adminVerifyAgent,
} from "../controllers/adminAgentController.js";

// Create router
const router = Router();

// GET: Admin - list all agent profiles
router.get(
  "/agents",
  requireAuth,
  requireRole(["admin"]),
  adminListAgents
);

router.get(
  "/transactions",
  requireAuth,
  requireRole(["admin"]),
  validate(adminTransactionsQuerySchema, "query"),
  adminListTransactions
);

router.get(
  "/transactions/:id",
  requireAuth,
  requireRole(["admin"]),
  adminGetTransaction
);

router.get(
  "/reports",
  requireAuth,
  requireRole(["admin"]),
  validate(adminReportsQuerySchema, "query"),
  adminGetReports
);

// PATCH: Admin - verify/approve or ban an agent
router.patch(
  "/agents/:id",
  requireAuth,
  requireRole(["admin"]),
  validate(adminAgentUpdateSchema),
  adminUpdateAgent
);

router.patch(
  "/agents/:id/verify",
  requireAuth,
  requireRole(["admin"]),
  adminVerifyAgent
);

router.patch(
  "/agents/:id/unverify",
  requireAuth,
  requireRole(["admin"]),
  adminUnverifyAgent
);

router.patch(
  "/agents/:id/ban",
  requireAuth,
  requireRole(["admin"]),
  adminBanAgent
);

router.patch(
  "/agents/:id/unban",
  requireAuth,
  requireRole(["admin"]),
  adminUnbanAgent
);

export default router;
