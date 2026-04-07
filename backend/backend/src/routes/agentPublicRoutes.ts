import { Router } from "express";
import axios from "axios";
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
const GOOGLE_API_KEY = process.env.GOOGLE_MAPS_API_KEY;
const geocodeCache = new Map<string, { lat: number; lng: number } | null>();

type AgentRow = {
  id: string;
  userId: string;
  status: string;
  isVerified: boolean;
  isBanned: boolean;
  available: boolean;
  cashLimit: unknown;
  locationName: string | null;
  city: string | null;
  latitude: number | null;
  longitude: number | null;
  ratingSum: number;
  ratingCount: number;
  createdAt: Date;
  updatedAt: Date;
  user: {
    id: string;
    name: string;
    email: string;
    phone: string | null;
    address: string | null;
    profileImage: string | null;
  };
};

function buildGeocodeQuery(agent: AgentRow): string {
  return [agent.locationName, agent.user.address, agent.city]
    .map((value) => (value ?? "").trim())
    .filter((value) => value.length > 0)
    .join(", ");
}

async function geocodeAddress(query: string): Promise<{ lat: number; lng: number } | null> {
  const normalized = query.trim().toLowerCase();
  if (!normalized) return null;
  if (geocodeCache.has(normalized)) {
    return geocodeCache.get(normalized) ?? null;
  }
  if (!GOOGLE_API_KEY) {
    geocodeCache.set(normalized, null);
    return null;
  }

  try {
    const response = await axios.get("https://maps.googleapis.com/maps/api/geocode/json", {
      params: {
        address: query,
        key: GOOGLE_API_KEY,
      },
    });
    const result = Array.isArray(response.data?.results) ? response.data.results[0] : null;
    const location = result?.geometry?.location;
    const lat = typeof location?.lat === "number" ? location.lat : null;
    const lng = typeof location?.lng === "number" ? location.lng : null;
    const coords = lat !== null && lng !== null ? { lat, lng } : null;
    geocodeCache.set(normalized, coords);
    return coords;
  } catch {
    geocodeCache.set(normalized, null);
    return null;
  }
}

async function resolveAgentCoordinates(agent: AgentRow): Promise<{ lat: number; lng: number } | null> {
  if (agent.latitude !== null && agent.longitude !== null) {
    return { lat: agent.latitude, lng: agent.longitude };
  }

  const query = buildGeocodeQuery(agent);
  if (!query) return null;

  const coords = await geocodeAddress(query);
  if (!coords) return null;

  // Best-effort persistence so future calls use stored lat/lng.
  void prisma.agentProfile
    .update({
      where: { id: agent.id },
      data: { latitude: coords.lat, longitude: coords.lng },
    })
    .catch(() => {});

  return coords;
}

const defaultAgentSelect = {
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
} as const;

// GET /agents/nearby?lat=...&lng=...&radius=...
router.get("/nearby", async (req, res) => {
  // Parse query params to float
  const lat = req.query.lat ? parseFloat(req.query.lat as string) : undefined;
  const lng = req.query.lng ? parseFloat(req.query.lng as string) : undefined;
  const radius = req.query.radius ? parseFloat(req.query.radius as string) : 10; // default 10km
  const cityQuery = typeof req.query.city === "string" ? req.query.city.trim() : "";
  const locationQuery = typeof req.query.location === "string" ? req.query.location.trim() : "";
  const addressQuery = typeof req.query.address === "string" ? req.query.address.trim() : "";
  const genericQuery = typeof req.query.q === "string" ? req.query.q.trim() : "";
  const manualQuery = cityQuery || locationQuery || addressQuery || genericQuery;
  const includeAll =
    typeof req.query.includeAll === "string" &&
    req.query.includeAll.toLowerCase() === "true";

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

  // GPS-first flow: when lat/lng is present, always use geo filtering regardless of city text.
  if (lat !== undefined && lng !== undefined) {
    const agents = await prisma.agentProfile.findMany({
      where: {
        isVerified: true,
        isBanned: false,
        ...(includeAll
          ? {}
          : {
              status: "verified",
              available: true,
            }),
      },
      select: defaultAgentSelect,
    });

    const withDistance: Array<
      AgentRow & { distanceKm: number; shopName: string; latitude: number; longitude: number }
    > = [];

    for (const rawAgent of agents) {
      const agent = rawAgent as AgentRow;
      const coords = await resolveAgentCoordinates(agent);
      if (!coords) continue;

      const distanceKm = haversine(lat, lng, coords.lat, coords.lng);
      withDistance.push({
        ...agent,
        latitude: coords.lat,
        longitude: coords.lng,
        distanceKm,
        shopName: agent.locationName ?? "",
      });
    }

    const nearby = withDistance
      .filter((agent) => agent.distanceKm <= radius)
      .sort((a, b) => a.distanceKm - b.distanceKm);

    return res.json({
      agents: nearby,
      center: { lat, lng },
      radiusKm: radius,
    });
  }

  // Manual fallback flow: if GPS is unavailable, allow city-based lookup.
  if (manualQuery) {
    const agentsByCity = await prisma.agentProfile.findMany({
      where: {
        status: "verified",
        isVerified: true,
        isBanned: false,
        available: true,
        OR: [
          {
            city: {
              contains: manualQuery,
              mode: "insensitive",
            },
          },
          {
            locationName: {
              contains: manualQuery,
              mode: "insensitive",
            },
          },
          {
            user: {
              address: {
                contains: manualQuery,
                mode: "insensitive",
              },
            },
          },
        ],
      },
      select: defaultAgentSelect,
      orderBy: { createdAt: "desc" },
    });

    const normalized = agentsByCity.map((agent) => ({
      ...agent,
      distanceKm: null,
      shopName: agent.locationName ?? "",
    }));

    return res.json({
      agents: normalized,
      center: null,
      radiusKm: radius,
    });
  }

  return res.status(400).json({
    error: "Provide lat/lng for nearby discovery or city for manual fallback",
  });
});

export default router;