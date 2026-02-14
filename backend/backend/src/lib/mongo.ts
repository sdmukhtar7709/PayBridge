import mongoose from "mongoose";
import logger from "./logger.js";
import { env } from "../config/env.js";

const uri = env.MONGODB_URI || "mongodb://127.0.0.1:27017/authDB";

mongoose.set("strictQuery", true);

export async function connectMongo() {
  if (mongoose.connection.readyState === 1) {
    return;
  }

  try {
    await mongoose.connect(uri);
    logger.info(`Connected to MongoDB at ${uri}`);
  } catch (err) {
    logger.error("MongoDB connection failed", err);
    throw err;
  }
}
