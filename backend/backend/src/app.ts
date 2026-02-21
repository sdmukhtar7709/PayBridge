import express from "express";
import cors from "cors";
import helmet from "helmet";
import bodyParser from "body-parser";
import { env, allowedOrigins } from "./config/env.js";
import { PrismaClient } from "@prisma/client";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { readFileSync } from "fs";
import YAML from "yaml";
import pinoHttp from "pino-http";
import { auditLogger } from "./middleware/auditLogger.js";
import { randomUUID } from "crypto";

// Route imports
import adminAgentRoutes from "./routes/adminAgentRoutes.js";
import agentTransactionRoutes from "./routes/agentTransactionRoutes.js";
import authRegisterRoutes from "./routes/authRegisterRoutes.js";
import sessionRoutes from "./routes/session.js";
import healthRoutes from "./routes/healthRoutes.js";
import accountRoutes from "./routes/accountRoutes.js";
import transactionRoutes from "./routes/transactionRoutes.js";
import categoryRoutes from "./routes/categoryRoutes.js";
import metricsRoutes, {
  httpRequestCounter,
  httpRequestDurationSeconds,
} from "./routes/metricsRoutes.js";
import docsRoutes from "./routes/docsRoutes.js";
import versionRoutes from "./routes/versionRoutes.js";
import agentSelfRoutes from "./routes/agentSelfRoutes.js";
import agentPublicRoutes from "./routes/agentPublicRoutes.js";
import agentRegisterRoutes from "./routes/agentRegisterRoutes.js";
import mapsProxyRoutes from "./routes/mapsProxyRoutes.js";
import cashTransactionRoutes from "./routes/cashTransactionRoutes.js";
import authRoutes from "./routes/authRoutes.js";

// Middleware
import { requireAuth } from "./middleware/auth.js";
import { errorHandler } from "./middleware/errorHandler.js";
import { notFound } from "./middleware/notFound.js";
import { authRateLimit } from "./middleware/authRateLimit.js";
import { dataRateLimit } from "./middleware/rateLimits.js";
import logger from "./lib/logger.js";

const prisma = new PrismaClient();
const app = express();

const corsOrigins =
  env.nodeEnv === "development" || allowedOrigins.length === 0
    ? true
    : allowedOrigins;

app.use(helmet());
app.use(cors({ origin: corsOrigins, credentials: true }));
app.use(bodyParser.json());

app.use(
  pinoHttp({
    logger,
    genReqId: (req, res) => {
      const header = req.headers["x-request-id"];
      if (header && typeof header === "string") return header;
      const id = randomUUID();
      res.setHeader("x-request-id", id);
      return id;
    },
    serializers: {
      req(req) {
        return { id: req.id, method: req.method, url: req.url };
      },
      res(res) {
        return { statusCode: res.statusCode };
      },
    },
  })
);

app.use(auditLogger);

// Prometheus metrics middleware
app.use((req, res, next) => {
  const start = process.hrtime.bigint();
  res.on("finish", () => {
    const rawRoute =
      req.route?.path || req.originalUrl?.split("?")[0] || "unknown";
    const routeLabel = rawRoute.replace(
      /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}/g,
      ":id"
    );
    const labels = {
      method: req.method,
      route: routeLabel,
      status_code: res.statusCode,
    };
    httpRequestCounter.inc(labels);
    const durationSeconds = Number(process.hrtime.bigint() - start) / 1e9;
    httpRequestDurationSeconds.observe(labels, durationSeconds);
  });
  next();
});

// Health endpoint using Prisma
app.get("/health", async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return res.json({ ok: true, db: "up" });
  } catch {
    return res.status(500).json({ ok: false, db: "down" });
  }
});

// Signup endpoint
app.post("/auth/signup", async (req, res) => {
  const { name, email, password } = req.body ?? {};
  if (!name || !email || !password) {
    return res.status(400).json({ error: "name, email, password required" });
  }

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    return res.status(409).json({ error: "User already exists" });
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await prisma.user.create({
    data: { name, email, passwordHash },
    select: { id: true, name: true, email: true, createdAt: true },
  });

  return res.status(201).json({ user });
});

// Login endpoint
app.post("/auth/login", async (req, res) => {
  const { email, password } = req.body ?? {};
  if (!email || !password) {
    return res.status(400).json({ error: "email and password required" });
  }

  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) {
    return res.status(401).json({ error: "Invalid credentials" });
  }

  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) {
    return res.status(401).json({ error: "Invalid credentials" });
  }

  const accessToken = jwt.sign(
    { sub: user.id, email: user.email },
    env.jwtSecret,
    { expiresIn: "15m" }
  );

  return res.json({
    accessToken,
    user: { id: user.id, name: user.name, email: user.email },
  });
});

// Mount all routers/middleware
app.use("/admin", adminAgentRoutes);
app.use("/", authRegisterRoutes);
app.use("/", healthRoutes);
app.use("/version", versionRoutes);
app.use("/agent", requireAuth, agentSelfRoutes);
app.use("/agents", agentPublicRoutes);
app.use("/transactions", cashTransactionRoutes);
app.use("/maps", mapsProxyRoutes);
app.use("/auth", authRateLimit, sessionRoutes);
app.use("/accounts", dataRateLimit, accountRoutes);
app.use("/", agentRegisterRoutes);
app.use("/agent/transactions", requireAuth, agentTransactionRoutes);
app.use("/transactions", dataRateLimit, transactionRoutes);
app.use("/categories", dataRateLimit, categoryRoutes);
app.use("/metrics", metricsRoutes);
app.use("/docs", docsRoutes);

// OpenAPI JSON endpoint
app.get("/docs/openapi.json", (req, res, next) => {
  try {
    const yamlPath = new URL("../docs/openapi.yaml", import.meta.url);
    const raw = readFileSync(yamlPath, "utf8");
    const doc = YAML.parse(raw);
    res.type("application/json").send(doc);
  } catch (err) {
    next(err);
  }
});

// 404 and error handlers
app.use(notFound);
app.use(errorHandler);

export { app, prisma };
