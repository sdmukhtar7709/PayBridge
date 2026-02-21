import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import crypto from "crypto";
import { Prisma } from "@prisma/client";
import prisma from "../lib/prisma.js";
import { LoginInput, SignupInput } from "../schemas/authSchemas.js";

const JWT_SECRET = process.env.JWT_SECRET || "change-me";
const SALT_ROUNDS = 10;

export async function signup(data: SignupInput) {
  const email = data.email.toLowerCase();
  const passwordHash = await bcrypt.hash(data.password, SALT_ROUNDS);

  try {
    const user = await prisma.user.create({
      data: {
        id: crypto.randomUUID(),
        name: data.name,
        email,
        passwordHash,
      },
    });

    const token = jwt.sign({ sub: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: "12h" });
    return { token, user: { id: user.id, name: user.name, email: user.email } };
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2002") {
      throw new Error("Email already registered");
    }
    throw err;
  }
}

export async function login(data: LoginInput) {
  const email = data.email.toLowerCase();
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) throw new Error("Invalid credentials");

  const ok = await bcrypt.compare(data.password, user.passwordHash);
  if (!ok) throw new Error("Invalid credentials");

  const token = jwt.sign({ sub: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: "12h" });
  return { token, user: { id: user.id, name: user.name, email: user.email } };
}
