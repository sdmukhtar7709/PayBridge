import dotenv from "dotenv";
import { z } from "zod";

dotenv.config();

const schema = z.object({
  NODE_ENV: z.string().default("development"),
  PORT: z.string().optional(),
  DATABASE_URL: z.string().nonempty(),
  JWT_SECRET: z.string(),
  ALLOWED_ORIGINS: z.string().optional(), // comma-separated
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  console.error("Invalid environment variables", parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
export const allowedOrigins = env.ALLOWED_ORIGINS
  ? env.ALLOWED_ORIGINS.split(",").map((s) => s.trim()).filter(Boolean)
  : [];
