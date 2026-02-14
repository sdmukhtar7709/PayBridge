import type { NextFunction, Request, Response } from "express";
import logger from "../lib/logger.js";

const MUTATING = new Set(["POST", "PUT", "PATCH", "DELETE"]);
const REDACT_KEYS = new Set(["password", "token", "authorization"]);

function sanitizeBody(body: unknown) {
  if (!body || typeof body !== "object") return undefined;
  const entries = Object.entries(body as Record<string, unknown>).slice(0, 20); // cap keys
  const result: Record<string, unknown> = {};
  for (const [key, value] of entries) {
    if (REDACT_KEYS.has(key.toLowerCase())) {
      result[key] = "[redacted]";
    } else if (typeof value === "string" && value.length > 200) {
      result[key] = value.slice(0, 200) + "...";
    } else {
      result[key] = value;
    }
  }
  return result;
}

export function auditLogger(req: Request, res: Response, next: NextFunction) {
  if (!MUTATING.has(req.method)) return next();

  const start = process.hrtime.bigint();

  res.on("finish", () => {
    const durationMs = Number(process.hrtime.bigint() - start) / 1e6;
    const userId = (req as any).user?.id ?? "anonymous";
    const path = req.originalUrl?.split("?")[0] ?? req.originalUrl;

    logger.info(
      {
        event: "audit",
        method: req.method,
        path,
        status: res.statusCode,
        userId,
        requestId: (req as any).id,
        durationMs,
        body: sanitizeBody(req.body),
      },
      "audit"
    );
  });

  next();
}
