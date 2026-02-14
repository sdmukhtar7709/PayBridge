import { Router } from "express";
import client from "prom-client";
import { requireAuth } from "../middleware/auth.js";
import { requireRole } from "../middleware/requireRole.js";

const router = Router();

client.collectDefaultMetrics({ prefix: "cash_platform_" });

export const httpRequestCounter = new client.Counter({
  name: "cash_platform_http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "route", "status_code"],
});
client.register.registerMetric(httpRequestCounter);

export const httpRequestDurationSeconds = new client.Histogram({
  name: "cash_platform_http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
});
client.register.registerMetric(httpRequestDurationSeconds);

// 🔐 ADMIN ONLY METRICS
router.get(
  "/",
  requireAuth,
  requireRole(["admin"]),
  async (_req, res) => {
    res.set("Content-Type", client.register.contentType);
    res.end(await client.register.metrics());
  }
);

export default router;
