import { Router } from "express";
import axios from "axios";

const GOOGLE_API_KEY = process.env.GOOGLE_MAPS_API_KEY;

const router = Router();

router.get("/nearby-banks-atms", async (req, res) => {
  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);
  const radius = Number(req.query.radius ?? 3000);

  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return res.status(400).json({ error: "lat and lng are required" });
  }

  const baseParams = {
    key: GOOGLE_API_KEY,
    location: `${lat},${lng}`,
    radius,
  };

  try {
    const nearbyUrl = "https://maps.googleapis.com/maps/api/place/nearbysearch/json";

    const [atmResp, bankResp] = await Promise.all([
      axios.get(nearbyUrl, { params: { ...baseParams, type: "atm" } }),
      axios.get(nearbyUrl, { params: { ...baseParams, type: "bank" } }),
    ]);

    const combined = [
      ...(atmResp.data?.results ?? []),
      ...(bankResp.data?.results ?? []),
    ];

    const deduped = Array.from(
      new Map(combined.map((item: any) => [item.place_id, item])).values()
    );

    return res.json({
      results: deduped,
      atmStatus: atmResp.data?.status,
      bankStatus: bankResp.data?.status,
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

export default router;