import rateLimit from "express-rate-limit";

// Already have authRateLimit; keep it separate.
// General limiter for data routes
export const dataRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 200, // per IP per window
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many requests, please try again later." },
});
