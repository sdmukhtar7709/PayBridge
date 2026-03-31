import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { Prisma } from "@prisma/client";
import prisma from "../../../lib/prisma.js";
import { env } from "../../../config/env.js";
import {
  AdminRegisterInput,
  LoginInput,
  RegisterInput,
} from "../schemas/auth.schema.js";

const SALT_ROUNDS = 10;

function authValidationError() {
  return {
    statusCode: 401,
    body: {
      error: {
        code: "INVALID_CREDENTIALS",
        message: "Username or password wrong",
      },
    },
  };
}

function signToken(user: { id: string; email: string; role: string }) {
  return jwt.sign(
    { sub: user.id, email: user.email, role: user.role },
    env.jwtSecret,
    { expiresIn: "12h" }
  );
}

export async function registerUser(data: RegisterInput) {
  const email = data.email.trim().toLowerCase();
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    throw Object.assign(new Error("Email already registered"), { statusCode: 409 });
  }

  const passwordHash = await bcrypt.hash(data.password, SALT_ROUNDS);
  const fallbackName = email.split("@")[0] || "User";

  try {
    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
        name: data.name?.trim() || fallbackName,
        phone: data.phone?.trim() || null,
        role: "user",
      },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        createdAt: true,
      },
    });

    const token = signToken({ id: user.id, email: user.email, role: user.role });
    return { success: true, token, user };
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      throw Object.assign(new Error("Email already registered"), { statusCode: 409 });
    }
    throw error;
  }
}

export async function registerAdminUser(data: AdminRegisterInput) {
  const email = data.email.trim().toLowerCase();
  if (data.registrationCode !== env.adminRegistrationCode) {
    throw Object.assign(new Error("Invalid admin registration code"), {
      statusCode: 403,
    });
  }

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    throw Object.assign(new Error("Email already registered"), {
      statusCode: 409,
    });
  }

  const passwordHash = await bcrypt.hash(data.password, SALT_ROUNDS);

  try {
    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
        name: data.name.trim(),
        phone: data.phone?.trim() || null,
        role: "admin",
      },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        createdAt: true,
      },
    });

    const token = signToken({ id: user.id, email: user.email, role: user.role });
    return { success: true, token, user };
  } catch (error) {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === "P2002"
    ) {
      throw Object.assign(new Error("Email already registered"), {
        statusCode: 409,
      });
    }
    throw error;
  }
}

export async function loginUser(data: LoginInput) {
  const email = data.email.trim().toLowerCase();
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user || user.role !== "user") {
    throw authValidationError();
  }

  const validPassword = await bcrypt.compare(data.password, user.passwordHash);
  if (!validPassword) {
    throw authValidationError();
  }

  const token = signToken({ id: user.id, email: user.email, role: user.role });
  return {
    success: true,
    token,
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      createdAt: user.createdAt,
    },
  };
}
