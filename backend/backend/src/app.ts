import express from "express";
import cors from "cors";
import helmet from "helmet";
import bodyParser from "body-parser";
import type { Request, Response } from "express";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { env, allowedOrigins } from "./config/env.js";
import { PrismaClient } from "@prisma/client";
import { readFileSync } from "fs";
import YAML from "yaml";
import pinoHttp from "pino-http";
import { auditLogger } from "./middleware/auditLogger.js";
import { randomUUID } from "crypto";

// Route imports
import adminAgentRoutes from "./routes/adminAgentRoutes.js";
import agentTransactionRoutes from "./routes/agentTransactionRoutes.js";
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
import authRoutes from "./features/auth/routes/auth.routes.js";
import userRoutes from "./routes/user.routes.js";

// Middleware
import { requireAuth } from "./middleware/auth.js";
import { errorHandler } from "./middleware/errorHandler.js";
import { notFound } from "./middleware/notFound.js";
import { authRateLimit } from "./middleware/authRateLimit.js";
import { dataRateLimit } from "./middleware/rateLimits.js";
import logger from "./lib/logger.js";

const prisma = new PrismaClient();
const app = express();
const pinoHttpMiddleware = pinoHttp as unknown as (options: unknown) => express.RequestHandler;
const currentFilePath = fileURLToPath(import.meta.url);
const currentDirPath = path.dirname(currentFilePath);
const adminUiPath = path.resolve(currentDirPath, "../../../admin");

const allowAnyOrigin =
  env.nodeEnv === "development" ||
  allowedOrigins.length === 0 ||
  allowedOrigins.includes("*");

const corsOptions: cors.CorsOptions = {
  credentials: true,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization", "X-Request-Id"],
  exposedHeaders: ["X-Request-Id"],
  maxAge: 86400,
  origin: (origin, callback) => {
    if (allowAnyOrigin) {
      callback(null, true);
      return;
    }

    // Allow non-browser clients without Origin header.
    if (!origin) {
      callback(null, true);
      return;
    }

    if (allowedOrigins.includes(origin)) {
      callback(null, true);
      return;
    }

    callback(new Error("Not allowed by CORS"));
  },
};

const mountWithApiAlias = (routePath: string, ...handlers: unknown[]) => {
  app.use(routePath, ...(handlers as Parameters<typeof app.use>[1][]));
  const apiRoutePath = routePath === "/" ? "/api" : `/api${routePath}`;
  app.use(apiRoutePath, ...(handlers as Parameters<typeof app.use>[1][]));
};

app.use(helmet());
app.use(cors(corsOptions));
app.options("*", cors(corsOptions));
app.use(bodyParser.json({ limit: "10mb" }));
app.use(bodyParser.urlencoded({ extended: true, limit: "10mb" }));

app.use(
  pinoHttpMiddleware({
    logger,
    genReqId: (req: Request, res: Response) => {
      const header = req.headers["x-request-id"];
      if (header && typeof header === "string") return header;
      const id = randomUUID();
      res.setHeader("x-request-id", id);
      return id;
    },
    serializers: {
      req(req: Request & { id?: string }) {
        return { id: req.id, method: req.method, url: req.url };
      },
      res(res: Response) {
        return { statusCode: res.statusCode };
      },
    },
  })
);

app.use(auditLogger);

// Serve static admin UI without colliding with existing /admin API routes.
app.use("/admin-ui", express.static(adminUiPath));
app.get("/admin-ui", (_req, res) => {
  res.redirect("/admin-ui/AuthScreen/index.html");
});
app.get("/admin/AuthScreen/index.html", (_req, res) => {
  res.redirect("/admin-ui/AuthScreen/index.html");
});
app.get("/admin/index.html", (_req, res) => {
  res.redirect("/admin-ui/index.html");
});

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
const healthHandler: express.RequestHandler = async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return res.json({ ok: true, db: "up" });
  } catch {
    return res.status(500).json({ ok: false, db: "down" });
  }
};

app.get("/health", healthHandler);
app.get("/api/health", healthHandler);

// Mount all routers/middleware
mountWithApiAlias("/admin", adminAgentRoutes);
mountWithApiAlias("/", healthRoutes);
mountWithApiAlias("/version", versionRoutes);
mountWithApiAlias("/agent", requireAuth, agentSelfRoutes);
mountWithApiAlias("/agents", agentPublicRoutes);
mountWithApiAlias("/transactions", cashTransactionRoutes);
mountWithApiAlias("/maps", mapsProxyRoutes);
mountWithApiAlias("/auth", authRateLimit, authRoutes);
mountWithApiAlias("/auth", authRateLimit, sessionRoutes);
mountWithApiAlias("/user", dataRateLimit, userRoutes);
mountWithApiAlias("/accounts", dataRateLimit, accountRoutes);
mountWithApiAlias("/", agentRegisterRoutes);
mountWithApiAlias("/agent/transactions", requireAuth, agentTransactionRoutes);
mountWithApiAlias("/transactions", dataRateLimit, transactionRoutes);
mountWithApiAlias("/categories", dataRateLimit, categoryRoutes);
mountWithApiAlias("/metrics", metricsRoutes);
mountWithApiAlias("/docs", docsRoutes);

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

app.get("/api/docs/openapi.json", (req, res, next) => {
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
