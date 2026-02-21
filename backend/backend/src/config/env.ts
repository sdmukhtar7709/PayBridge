import dotenv from "dotenv";

dotenv.config();

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

// Use a comma-separated list from .env for allowed origins, or an empty array as default
export const allowedOrigins = (process.env.ALLOWED_ORIGINS ?? "")
  .split(",")
  .map((origin) => origin.trim())
  .filter((origin) => origin);

export const env = {
  nodeEnv: process.env.NODE_ENV ?? "development",
  port: Number(process.env.PORT ?? "4000"),
  databaseUrl: requireEnv("DATABASE_URL"),
  jwtSecret: process.env.JWT_SECRET ?? "dev-secret-change-me",
};
