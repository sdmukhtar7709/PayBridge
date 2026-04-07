import { Router } from "express";
import axios from "axios";

const GOOGLE_API_KEY = process.env.GOOGLE_MAPS_API_KEY;

const router = Router();

const GOOGLE_NEARBY_URL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json";
const NEXT_PAGE_TOKEN_DELAY_MS = 2000;
const MAX_NEARBY_PAGES = 3;

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchNearbyByType(
  baseParams: { key: string | undefined; location: string; radius: number },
  placeType: "atm" | "bank"
) {
  const results: any[] = [];
  const statuses: string[] = [];
  let nextPageToken: string | undefined;

  for (let page = 0; page < MAX_NEARBY_PAGES; page += 1) {
    const params =
      page === 0
        ? { ...baseParams, type: placeType }
        : { key: baseParams.key, pagetoken: nextPageToken };

    if (page > 0) {
      // Google requires a short delay before next_page_token becomes valid.
      await delay(NEXT_PAGE_TOKEN_DELAY_MS);
    }

    const response = await axios.get(GOOGLE_NEARBY_URL, { params });
    const data = response.data ?? {};
    const status = typeof data.status === "string" ? data.status : "UNKNOWN";
    statuses.push(status);

    if (Array.isArray(data.results) && data.results.length > 0) {
      results.push(...data.results);
    }

    if (!data.next_page_token || status !== "OK") {
      break;
    }
    nextPageToken = data.next_page_token;
  }

  return {
    results,
    statuses,
  };
}

router.get("/nearby-banks-atms", async (req, res) => {
  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);
  const radius = Number(req.query.radius ?? 10000);

  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return res.status(400).json({ error: "lat and lng are required" });
  }

  const baseParams = {
    key: GOOGLE_API_KEY,
    location: `${lat},${lng}`,
    radius,
  };

  try {
    const [atmData, bankData] = await Promise.all([
      fetchNearbyByType(baseParams, "atm"),
      fetchNearbyByType(baseParams, "bank"),
    ]);

    const combined = [
      ...atmData.results,
      ...bankData.results,
    ];

    const deduped = Array.from(
      new Map(combined.map((item: any) => [item.place_id, item])).values()
    );

    const bankAtmOnly = deduped.filter((item: any) => {
      const types = Array.isArray(item?.types) ? item.types : [];
      return types.includes("bank") || types.includes("atm");
    });

    const atmStatus = atmData.statuses[atmData.statuses.length - 1] ?? "UNKNOWN";
    const bankStatus = bankData.statuses[bankData.statuses.length - 1] ?? "UNKNOWN";

    return res.json({
      results: bankAtmOnly,
      atmStatus,
      bankStatus,
      atmStatuses: atmData.statuses,
      bankStatuses: bankData.statuses,
    });
  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : String(err);
    return res.status(500).json({ error: "Google NearbySearch error", details: errorMessage });
  }
});

// You may want to limit to authenticated agents for abuse prevention
router.get("/places-autocomplete", async (req, res) => {
  const input = req.query.input as string;
  if (!input) return res.status(400).json({ error: "input required" });

  const params = {
    input,
    key: GOOGLE_API_KEY,
    types: "establishment", // businesses only; change as needed
    components: "country:IN", // restrict to India; remove/change if global
  };

  try {
    const url = "https://maps.googleapis.com/maps/api/place/autocomplete/json";
    const resp = await axios.get(url, { params });
    res.json(resp.data);
  } catch (err) {
    const errorMessage = (err instanceof Error) ? err.message : String(err);
    res.status(500).json({ error: "Google Places error", details: errorMessage });
  }
});

// Get Place details (lat/lng!) after pick
router.get("/place-details", async (req, res) => {
  const placeId = req.query.placeId as string;
  if (!placeId) return res.status(400).json({ error: "placeId required" });

  const params = {
    place_id: placeId,
    key: GOOGLE_API_KEY,
    fields: "geometry,name,formatted_address"
  };

  try {
    const url = "https://maps.googleapis.com/maps/api/place/details/json";
    const resp = await axios.get(url, { params });
    res.json(resp.data);
  } catch (err) {
    const errorMessage = (err instanceof Error) ? err.message : String(err);
    res.status(500).json({ error: "Google PlaceDetails error", details: errorMessage });
  }
});

router.get("/directions", async (req, res) => {
  const originLat = Number(req.query.originLat);
  const originLng = Number(req.query.originLng);
  const destLat = Number(req.query.destLat);
  const destLng = Number(req.query.destLng);
  const mode = (req.query.mode as string | undefined) ?? "driving";

  if (
    !Number.isFinite(originLat) ||
    !Number.isFinite(originLng) ||
    !Number.isFinite(destLat) ||
    !Number.isFinite(destLng)
  ) {
    return res.status(400).json({ error: "originLat, originLng, destLat and destLng are required" });
  }

  try {
    const url = "https://maps.googleapis.com/maps/api/directions/json";
    const params = {
      origin: `${originLat},${originLng}`,
      destination: `${destLat},${destLng}`,
      mode,
      key: GOOGLE_API_KEY,
    };

    const response = await axios.get(url, { params });
    const data = response.data ?? {};
    const routes = Array.isArray(data.routes) ? data.routes : [];
    const firstRoute = routes[0];

    if (!firstRoute) {
      return res.status(404).json({ error: "No route found", status: data.status ?? "UNKNOWN" });
    }

    const legs = Array.isArray(firstRoute.legs) ? firstRoute.legs : [];
    const firstLeg = legs[0] ?? {};

    return res.json({
      status: data.status ?? "OK",
      distanceText: firstLeg?.distance?.text ?? "",
      distanceMeters: firstLeg?.distance?.value ?? null,
      durationText: firstLeg?.duration?.text ?? "",
      durationSeconds: firstLeg?.duration?.value ?? null,
      startAddress: firstLeg?.start_address ?? "",
      endAddress: firstLeg?.end_address ?? "",
      routePolyline: firstRoute?.overview_polyline?.points ?? "",
    });
  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : String(err);
    return res.status(500).json({ error: "Google Directions error", details: errorMessage });
  }
});

export default router;