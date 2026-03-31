import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth.js";
import { validate } from "../middleware/validate.js";
import {
  getProfileController,
  updateProfileController,
} from "../controllers/user.controller.js";

const router = Router();

const updateProfileSchema = z
  .object({
    firstName: z.string().trim().optional(),
    lastName: z.string().trim().optional(),
    phone: z.string().trim().optional(),
    gender: z.string().trim().optional(),
    maritalStatus: z.string().trim().optional(),
    age: z.coerce.number().int().min(1).max(120).optional(),
    address: z.string().trim().optional(),
    city: z.string().trim().max(50).optional(),
    profileImage: z.string().trim().optional(),
  })
  .strict();

router.get("/profile", requireAuth, getProfileController);
router.put(
  "/profile",
  requireAuth,
  validate(updateProfileSchema),
  updateProfileController
);

export default router;
