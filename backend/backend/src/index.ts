import { app } from "./app.js";
import { env } from "./config/env.js";
import logger from "./lib/logger.js";

const PORT = Number(env.PORT) || 3000;
const server = app.listen(PORT, () => {
  logger.info(`API running on port ${PORT}`);
});

server.on("error", (err: any) => {
  if (err?.code === "EADDRINUSE") {
    logger.error(`Port ${PORT} is already in use`);
    process.exit(1);
  }
  logger.error(err);
});
