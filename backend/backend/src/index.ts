import { app } from "./app";
import { env } from "./config/env";
import prisma from "./lib/prisma.js";
import logger from "./lib/logger.js";
import type { Server } from "node:http";

const PORT = env.port || 5000;
const HOST = "0.0.0.0";
const divider = "-".repeat(60);
const MAX_PORT_RETRIES = 20;

type AddressInUseError = Error & {
  code?: string;
};

// 🎯 Startup Banner (SAFE ASCII)
function logStartupBanner() {
  console.log("\n");
  logger.info(divider);
  logger.info("CASH IO BACKEND STARTING");
  logger.info(divider);

  logger.info(`Environment : ${env.nodeEnv}`);
  logger.info(`Port        : ${PORT} (preferred)`);
  logger.info(`Start Time  : ${new Date().toLocaleString()}`);
  logger.info(divider);
}

// 🔌 Database Connection
async function connectDatabase() {
  logger.info("Connecting to database...");
  try {
    await prisma.$connect();
    logger.info("Database connected successfully");
  } catch (error) {
    logger.error({ err: error }, "Database connection failed");
    process.exit(1);
  }
}

// 🚀 Start Server
function startServer(port: number): Promise<Server> {
  return new Promise((resolve, reject) => {
    const server = app.listen(port, HOST, () => {
      logger.info(divider);
      logger.info("SERVER STARTED SUCCESSFULLY");
      logger.info(divider);

      logger.info(`API Server   : http://localhost:${port}`);
      logger.info(`Admin Panel  : http://localhost:${port}/admin-ui/AuthScreen/index.html`);
      logger.info(`API Base URL : http://localhost:${port}/api`);
      logger.info(`Prisma Studio: http://localhost:5555`);
      logger.info(`Studio Cmd   : npm run studio`);
      logger.info(`Alt Cmd      : npx prisma studio`);
      

      logger.info(divider);
      logger.info("System ready to accept requests");
      logger.info(divider);

      resolve(server);
    });

    server.on("error", (error: Error) => {
      if (isAddressInUse(error)) {
        logger.warn({ err: error }, "Port in use while starting server");
      } else {
        logger.error({ err: error }, "Server failed to start");
      }
      reject(error);
    });
  });
}

function isAddressInUse(error: unknown): boolean {
  const err = error as AddressInUseError;
  return err?.code === "EADDRINUSE";
}

async function startServerWithPortFallback(): Promise<{ server: Server; port: number }> {
  for (let offset = 0; offset <= MAX_PORT_RETRIES; offset += 1) {
    const candidatePort = PORT + offset;
    try {
      const server = await startServer(candidatePort);
      if (offset > 0) {
        logger.warn(
          `Preferred port ${PORT} is busy. Started on fallback port ${candidatePort}.`
        );
      }
      return { server, port: candidatePort };
    } catch (error) {
      if (!isAddressInUse(error)) {
        throw error;
      }

      logger.warn(`Port ${candidatePort} is in use. Trying ${candidatePort + 1}...`);
    }
  }

  throw new Error(
    `No free port found from ${PORT} to ${PORT + MAX_PORT_RETRIES}.`
  );
}

// 🛑 Graceful Shutdown
async function shutdown(signal: string) {
  logger.warn(`Received ${signal}. Shutting down...`);

  try {
    await prisma.$disconnect();
    logger.info("Database disconnected");

    logger.info("Shutdown complete");
    process.exit(0);
  } catch (error) {
    logger.error({ err: error }, "Error during shutdown");
    process.exit(1);
  }
}

// 🧠 Bootstrap Application
async function bootstrap() {
  try {
    logStartupBanner();
    await connectDatabase();
    await startServerWithPortFallback();

    // Handle shutdown signals
    process.on("SIGINT", shutdown);
    process.on("SIGTERM", shutdown);
  } catch (error) {
    logger.error({ err: error }, "Application failed to start");
    process.exit(1);
  }
}

bootstrap();