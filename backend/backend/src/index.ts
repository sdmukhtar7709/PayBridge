import { app } from "./app";
import { env } from "./config/env";
import prisma from "./lib/prisma.js";

const port = env.port;

async function bootstrap() {
  try {
    await prisma.$connect();
    console.log("Database connected");

    app.listen(port, "0.0.0.0", () => {
      console.log(`Server running on http://localhost:${port}`);
    });
  } catch (error) {
    console.error("Failed to connect database:", error);
    process.exit(1);
  }
}

bootstrap();
