import { Request, Response } from "express";
import prisma from "../lib/prisma.js";
import {
  agentManageProfileSchema,
  agentProfileCreateSchema,
  agentProfilePatchSchema,
} from "../schemas/agentProfileSchemas.js";

function cleanOptionalString(value?: string) {
  if (value === undefined) return undefined;
  const trimmed = value.trim();
  return trimmed.length ? trimmed : null;
}

function deriveCity(value?: string | null) {
  if (!value) return null;
  const parts = value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  if (parts.length === 0) return null;
  return parts[parts.length - 1] || null;
}

// GET /agent/profile
export async function getAgentProfile(req: Request, res: Response) {
  const userId = (req as any).user?.id;
  if (!userId) return res.status(401).json({ error: "Unauthorized" });

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      name: true,
      email: true,
      role: true,
      firstName: true,
      lastName: true,
      phone: true,
      address: true,
      gender: true,
      maritalStatus: true,
      age: true,
      profileImage: true,
      createdAt: true,
      updatedAt: true,
      agentProfile: true,
    },
  });

  if (!user || user.role !== "agent") {
    return res.status(404).json({ error: "Agent profile not found" });
  }

  return res.json({
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
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
}

// POST /agent/profile
export async function createAgentProfile(req: Request, res: Response) {
  const userId = (req as any).user?.id;
  if (!userId) return res.status(401).json({ error: "Unauthorized" });

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { role: true },
  });
  if (!user || user.role !== "agent") {
    return res.status(403).json({ error: "Only agents can create an agent profile." });
  }

  // Prevent duplicates: each user can have only one agent profile
  const existing = await prisma.agentProfile.findUnique({ where: { userId } });
  if (existing) return res.status(400).json({ error: "You already have an agent profile." });

  // Validate input (only cashLimit supported for now)
  const parsed = agentProfileCreateSchema.safeParse(req.body);
  if (!parsed.success)
    return res.status(400).json({ error: parsed.error.flatten() });

  // Create with sensible defaults
  const agent = await prisma.agentProfile.create({
    data: {
      userId,
      cashLimit: parsed.data.cashLimit,
      isVerified: false,
      isBanned: false,
      available: false
      // Add more fields as needed
    },
    include: { user: true }
  });
  return res.status(201).json(agent);
}

// PATCH /agent/profile
export async function updateAgentProfile(req: Request, res: Response) {
  const userId = (req as any).user?.id;
  if (!userId) return res.status(401).json({ error: "Unauthorized" });

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { role: true },
  });
  if (!user || user.role !== "agent") {
    return res.status(403).json({ error: "Only agents can manage this profile." });
  }

  const existingAgentProfile = await prisma.agentProfile.findUnique({ where: { userId } });

  const manageParsed = agentManageProfileSchema.safeParse(req.body);

  let userUpdateData: Record<string, unknown> = {};
  let agentUpdateData: Record<string, unknown> = {};

  if (manageParsed.success) {
    const userData = manageParsed.data.user;
    const agentData = manageParsed.data.agentProfile;

    if (userData) {
      userUpdateData = {
        ...(userData.name !== undefined ? { name: cleanOptionalString(userData.name) } : {}),
        ...(userData.firstName !== undefined ? { firstName: cleanOptionalString(userData.firstName) } : {}),
        ...(userData.lastName !== undefined ? { lastName: cleanOptionalString(userData.lastName) } : {}),
        ...(userData.phone !== undefined ? { phone: cleanOptionalString(userData.phone) } : {}),
        ...(userData.gender !== undefined ? { gender: cleanOptionalString(userData.gender) } : {}),
        ...(userData.maritalStatus !== undefined
          ? { maritalStatus: cleanOptionalString(userData.maritalStatus) }
          : {}),
        ...(userData.address !== undefined ? { address: cleanOptionalString(userData.address) } : {}),
        ...(userData.profileImage !== undefined
          ? { profileImage: cleanOptionalString(userData.profileImage) }
          : {}),
        ...(userData.age !== undefined ? { age: userData.age } : {}),
      };
    }

    if (agentData) {
      const cityFromInput = cleanOptionalString(agentData.city);
      const cityFromAddress = deriveCity(userData?.address ?? undefined);
      const cityFromLocationName = deriveCity(agentData.locationName ?? undefined);
      const resolvedCity = cityFromInput ?? cityFromAddress ?? cityFromLocationName;

      agentUpdateData = {
        ...(agentData.cashLimit !== undefined ? { cashLimit: agentData.cashLimit } : {}),
        ...(agentData.available !== undefined ? { available: agentData.available } : {}),
        ...(
          agentData.city !== undefined
            ? { city: cityFromInput }
            : (!existingAgentProfile?.city && resolvedCity ? { city: resolvedCity } : {})
        ),
        ...(agentData.latitude !== undefined ? { latitude: agentData.latitude } : {}),
        ...(agentData.longitude !== undefined ? { longitude: agentData.longitude } : {}),
        ...(agentData.locationName !== undefined
          ? { locationName: cleanOptionalString(agentData.locationName) }
          : {}),
      };
    }
  } else {
    const parsed = agentProfilePatchSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.flatten() });
    }

    const cityFromInput = cleanOptionalString(parsed.data.city);
    const cityFromLocationName = deriveCity(parsed.data.locationName ?? undefined);
    const resolvedCity = cityFromInput ?? cityFromLocationName;

    agentUpdateData = {
      ...(parsed.data.cashLimit !== undefined ? { cashLimit: parsed.data.cashLimit } : {}),
      ...(parsed.data.available !== undefined ? { available: parsed.data.available } : {}),
      ...(
        parsed.data.city !== undefined
          ? { city: cityFromInput }
          : (!existingAgentProfile?.city && resolvedCity ? { city: resolvedCity } : {})
      ),
      ...(parsed.data.latitude !== undefined ? { latitude: parsed.data.latitude } : {}),
      ...(parsed.data.longitude !== undefined ? { longitude: parsed.data.longitude } : {}),
      ...(parsed.data.locationName !== undefined
        ? { locationName: cleanOptionalString(parsed.data.locationName) }
        : {}),
    };
  }

  const updated = await prisma.$transaction(async (tx) => {
    if (Object.keys(userUpdateData).length > 0) {
      await tx.user.update({
        where: { id: userId },
        data: userUpdateData,
      });
    }

    if (Object.keys(agentUpdateData).length > 0 || !existingAgentProfile) {
      await tx.agentProfile.upsert({
        where: { userId },
        update: agentUpdateData,
        create: {
          userId,
          cashLimit:
            typeof agentUpdateData.cashLimit === "number" ? agentUpdateData.cashLimit : 0,
          available:
            typeof agentUpdateData.available === "boolean" ? agentUpdateData.available : false,
          city:
            agentUpdateData.city !== undefined
              ? (agentUpdateData.city as string | null)
              : null,
          locationName:
            agentUpdateData.locationName !== undefined
              ? (agentUpdateData.locationName as string | null)
              : null,
          latitude:
            agentUpdateData.latitude !== undefined
              ? (agentUpdateData.latitude as number)
              : null,
          longitude:
            agentUpdateData.longitude !== undefined
              ? (agentUpdateData.longitude as number)
              : null,
          isVerified: false,
          isBanned: false,
        },
      });
    }

    return tx.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        firstName: true,
        lastName: true,
        phone: true,
        address: true,
        gender: true,
        maritalStatus: true,
        age: true,
        profileImage: true,
        createdAt: true,
        updatedAt: true,
        agentProfile: true,
      },
    });
  });

  return res.json({
    user: updated,
    agentProfile: updated?.agentProfile ?? null,
  });
}
