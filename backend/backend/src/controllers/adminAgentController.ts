import { Request, Response } from "express";
import {
  adminAgentUpdateSchema,
  adminReportsQuerySchema,
  adminTransactionsQuerySchema,
} from "../schemas/adminAgentSchemas.js";
import {
  AdminModerationError,
  getAdminTransactionDetails,
  getAdminReports,
  listAdminTransactions,
  listAdminAgents,
  moderateAgentByAction,
  updateAgentModerationGeneric,
} from "../services/adminAgentModeration.service.js";

function handleControllerError(res: Response, error: unknown, fallback: string) {
  if (error instanceof AdminModerationError) {
    return res.status(error.statusCode).json({ error: error.message });
  }

  return res.status(500).json({ error: fallback });
}

export async function adminListAgents(_req: Request, res: Response) {
  try {
    const agents = await listAdminAgents();
    return res.json(agents);
  } catch (error) {
    return handleControllerError(res, error, "Failed to fetch agents");
  }
}

export async function adminListTransactions(req: Request, res: Response) {
  try {
    const parsed = adminTransactionsQuerySchema.safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.flatten() });
    }

    const result = await listAdminTransactions(parsed.data);
    return res.json(result);
  } catch (error) {
    return handleControllerError(res, error, "Failed to fetch transactions");
  }
}

export async function adminGetTransaction(req: Request, res: Response) {
  try {
    const { id } = req.params;
    const result = await getAdminTransactionDetails(id);
    return res.json(result);
  } catch (error) {
    return handleControllerError(res, error, "Failed to fetch transaction details");
  }
}

export async function adminGetReports(req: Request, res: Response) {
  try {
    const parsed = adminReportsQuerySchema.safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.flatten() });
    }

    const result = await getAdminReports(parsed.data.days);
    return res.json(result);
  } catch (error) {
    return handleControllerError(res, error, "Failed to fetch reports");
  }
}

// PATCH /admin/agents/:id
export async function adminUpdateAgent(req: Request, res: Response) {
  try {
    const { id } = req.params;

    const parsed = adminAgentUpdateSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.flatten() });
    }

    const result = await updateAgentModerationGeneric(id, parsed.data);
    return res.json(result);
  } catch (error) {
    return handleControllerError(res, error, "Failed to update agent moderation");
  }
}

export async function adminVerifyAgent(req: Request, res: Response) {
  try {
    const result = await moderateAgentByAction(req.params.id, "verify");
    return res.json(result);
  } catch (error) {
    return handleControllerError(res, error, "Failed to verify agent");
  }
}

export async function adminUnverifyAgent(req: Request, res: Response) {
  try {
    const result = await moderateAgentByAction(req.params.id, "unverify");
    return res.json(result);
  } catch (error) {
    return handleControllerError(res, error, "Failed to unverify agent");
  }
}

export async function adminBanAgent(req: Request, res: Response) {
  try {
    const result = await moderateAgentByAction(req.params.id, "ban");
    return res.json(result);
  } catch (error) {
    return handleControllerError(res, error, "Failed to ban agent");
  }
}

export async function adminUnbanAgent(req: Request, res: Response) {
  try {
    const result = await moderateAgentByAction(req.params.id, "unban");
    return res.json(result);
  } catch (error) {
    return handleControllerError(res, error, "Failed to unban agent");
  }
}
