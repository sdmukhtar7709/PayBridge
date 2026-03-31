import { Router } from "express";
import prisma from "../lib/prisma.js";

// --- Helper for distance calculation using Haversine formula ---
function haversine(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const toRad = (deg: number) => deg * Math.PI / 180;
  const R = 6371; // Earth radius in km
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

const router = Router();

// GET /agents/nearby?lat=...&lng=...&radius=...
router.get("/nearby", async (req, res) => {
  // Parse query params to float
  const lat = req.query.lat ? parseFloat(req.query.lat as string) : undefined;
  const lng = req.query.lng ? parseFloat(req.query.lng as string) : undefined;
  const radius = req.query.radius ? parseFloat(req.query.radius as string) : 2; // default 2km
  const cityQuery = typeof req.query.city === "string" ? req.query.city.trim() : "";

  // Validate
  if (
    lat !== undefined && (isNaN(lat) || lat < -90 || lat > 90) ||
    lng !== undefined && (isNaN(lng) || lng < -180 || lng > 180)
  ) {
    return res.status(400).json({ error: "Invalid lat/lng" });
  }
  if (radius < 0.1 || radius > 100) {
    return res.status(400).json({ error: "Radius out of range (0.1–100km)" });
  }

  // If city is provided, city filter takes priority and returns all available agents in that city.
  if (cityQuery) {
    const agentsByCity = await prisma.agentProfile.findMany({
      where: {
        status: "verified",
        isBanned: false,
        city: {
          contains: cityQuery,
          mode: "insensitive",
        },
      },
      select: {
        id: true,
        userId: true,
        status: true,
        isVerified: true,
        isBanned: true,
        available: true,
        cashLimit: true,
        locationName: true,
        city: true,
        latitude: true,
        longitude: true,
        ratingSum: true,
        ratingCount: true,
        createdAt: true,
        updatedAt: true,
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            phone: true,
            address: true,
            profileImage: true,
          },
        },
      },
      orderBy: { createdAt: "desc" },
    });

    return res.json(agentsByCity);
  }

  // If no geo-coords provided, return all non-banned agents (dev-friendly fallback)
  if (lat === undefined || lng === undefined) {
    const agents = await prisma.agentProfile.findMany({
      where: {
        status: "verified",
        isBanned: false,
      },
      select: {
        id: true,
        userId: true,
        status: true,
        isVerified: true,
        isBanned: true,
        available: true,
        cashLimit: true,
        locationName: true,
        city: true,
        latitude: true,
        longitude: true,
        ratingSum: true,
        ratingCount: true,
        createdAt: true,
        updatedAt: true,
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            phone: true,
            address: true,
            profileImage: true,
          },
        },
      },
    });
    return res.json(agents);
  }

  // Grab geo-enabled agents from DB
  const agents = await prisma.agentProfile.findMany({
    where: {
      status: "verified",
      isBanned: false,
      latitude: { not: null },
      longitude: { not: null },
    },
    select: {
      id: true,
      userId: true,
      status: true,
      isVerified: true,
      isBanned: true,
      available: true,
      cashLimit: true,
      locationName: true,
      city: true,
      latitude: true,
      longitude: true,
      ratingSum: true,
      ratingCount: true,
      createdAt: true,
      updatedAt: true,
      user: {
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          address: true,
          profileImage: true,
        },
      },
    },
  });

  // Filter by distance using Haversine (in JavaScript)
  const filtered = agents.filter(agent =>
    haversine(lat, lng, agent.latitude as number, agent.longitude as number) <= radius
  );

  res.json(filtered);
});

export default router;