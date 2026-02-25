import { Router } from "express";
import { createAgentProfile, getAgentProfile, updateAgentProfile } from "../controllers/agentSelfController.js";
import { validate } from "../middleware/validate.js";
import { agentProfileCreateSchema, agentProfilePatchSchema } from "../schemas/agentProfileSchemas.js";

const router = Router();

// GET /agent/profile - get own profile
router.get("/profile", getAgentProfile);

// POST /agent/profile - create own profile
router.post("/profile", validate(agentProfileCreateSchema), createAgentProfile);

// PATCH /agent/profile - update own profile
router.patch("/profile", validate(agentProfilePatchSchema), updateAgentProfile);

export default router;
