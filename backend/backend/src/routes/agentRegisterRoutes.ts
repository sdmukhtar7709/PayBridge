import { Router } from "express";
import prisma from "../lib/prisma.js";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { env } from "../config/env.js";
import { z } from "zod";

const router = Router();

const registerAgentSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  name: z.string().trim().min(1).optional(),
  firstName: z.string().trim().optional(),
  lastName: z.string().trim().optional(),
  phone: z.string().trim().optional(),
  gender: z.string().trim().optional(),
  maritalStatus: z.string().trim().optional(),
  age: z.coerce.number().int().min(1).max(120).optional(),
  address: z.string().trim().optional(),
  profileImage: z.string().trim().optional(),
  locationName: z.string().trim().min(1),
  city: z.string().trim().max(50).optional(),
  cashLimit: z.coerce.number().positive(),
});

const loginAgentSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

function deriveCity(value?: string | null): string | null {
  if (!value) return null;
  const parts = value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  if (parts.length === 0) return null;
  return parts[parts.length - 1] || null;
}

function normalizeCity(inputCity?: string, address?: string, locationName?: string) {
  const direct = inputCity?.trim();
  if (direct) return direct;
  return deriveCity(address) ?? deriveCity(locationName);
}

function signToken(user: { id: string; email: string; role: string }) {
  return jwt.sign(
    { sub: user.id, email: user.email, role: user.role },
    env.jwtSecret,
    { expiresIn: "12h" }
  );
}

router.post("/register-agent", async (req, res) => {
  const parsed = registerAgentSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({
      error: "Invalid request",
      details: parsed.error.errors.map((err) => ({
        path: err.path.join("."),
        message: err.message,
      })),
    });
  }

  const {
    email,
    password,
    name,
    firstName,
    lastName,
    phone,
    gender,
    maritalStatus,
    age,
    address,
    profileImage,
    locationName,
    city,
    cashLimit,
  } = parsed.data;

  const normalizedEmail = email.trim().toLowerCase();

  const existingUser = await prisma.user.findUnique({ where: { email: normalizedEmail } });
  if (existingUser) return res.status(409).json({ error: "Email already registered" });

  const normalizedFirstName = firstName?.trim() || null;
  const normalizedLastName = lastName?.trim() || null;
  const fullName = name?.trim() || [normalizedFirstName, normalizedLastName].filter(Boolean).join(" ").trim() || email.split("@")[0] || "Agent";
  const normalizedAddress = address?.trim() || null;
  const normalizedLocationName = locationName.trim();
  const normalizedCity = normalizeCity(city, normalizedAddress ?? undefined, normalizedLocationName) ?? null;

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await prisma.user.create({
    data: {
      email: normalizedEmail,
      passwordHash,
      name: fullName,
      role: "agent", // assign "agent" role directly
      firstName: normalizedFirstName,
      lastName: normalizedLastName,
      phone: phone?.trim() || null,
      gender: gender?.trim() || null,
      maritalStatus: maritalStatus?.trim() || null,
      age: age ?? null,
      address: normalizedAddress,
      profileImage: profileImage?.trim() || null,
    },
  });

  const agentProfile = await prisma.agentProfile.create({
    data: {
      userId: user.id,
      locationName: normalizedLocationName,
      city: normalizedCity,
      cashLimit,
      status: "pending",
      isVerified: false,
      isBanned: false,
      available: false,
    } as any,
  });

  const token = signToken({ id: user.id, email: user.email, role: user.role });

  res.status(201).json({
    success: true,
    token,
    user: {
      id: user.id,
      email: user.email,
      role: user.role,
      name: user.name,
      firstName: user.firstName,
      lastName: user.lastName,
      phone: user.phone,
      address: user.address,
      gender: user.gender,
      maritalStatus: user.maritalStatus,
      age: user.age,
      profileImage: user.profileImage,
    },
    agentProfile,
  });
});

router.post("/login-agent", async (req, res) => {
  const parsed = loginAgentSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: "Invalid request" });
  }

  const { email, password } = parsed.data;
  const user = await prisma.user.findUnique({
    where: { email: email.trim().toLowerCase() },
    include: { agentProfile: true },
  });

  if (!user || user.role !== "agent") {
    return res.status(401).json({
      error: {
        code: "INVALID_CREDENTIALS",
        message: "Invalid login credentials",
        details: [{ path: "email", message: "Email not found" }],
      },
    });
  }

  const valid = await bcrypt.compare(password, user.passwordHash);
  if (!valid) {
    return res.status(401).json({
      error: {
        code: "INVALID_CREDENTIALS",
        message: "Invalid login credentials",
        details: [{ path: "password", message: "Password is incorrect" }],
      },
    });
  }

  const token = signToken({ id: user.id, email: user.email, role: user.role });

  return res.status(200).json({
    success: true,
    token,
    user: {
      id: user.id,
      email: user.email,
      role: user.role,
      name: user.name,
      firstName: user.firstName,
      lastName: user.lastName,
      phone: user.phone,
      address: user.address,
      gender: user.gender,
      maritalStatus: user.maritalStatus,
      age: user.age,
      profileImage: user.profileImage,
    },
    agentProfile: user.agentProfile,
  });
});

export default router;
