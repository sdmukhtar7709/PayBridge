import { app } from "./app";
import { env } from "./config/env";
import prisma from "./lib/prisma.js";
import logger from "./lib/logger.js";

const port = env.port;
const divider = "-".repeat(60);

function logStartupBanner() {
  logger.info(divider);
  logger.info("Cash IO Backend");
  logger.info(divider);
  logger.info({ env: env.nodeEnv, port }, "Environment loaded");
}

async function bootstrap() {
  try {
    logStartupBanner();
    logger.info("Connecting to database...");
    await prisma.$connect();
    logger.info("Database connected");

    app.listen(port, "0.0.0.0", () => {
      logger.info(`Server running on http://localhost:${port}`);
    });
  } catch (error) {
    logger.error({ err: error }, "Failed to connect database");
    process.exit(1);
  }
}

bootstrap();
