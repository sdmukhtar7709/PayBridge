import { Router } from "express";
import { createAgentProfile, getAgentProfile, updateAgentProfile } from "../controllers/agentSelfController.js";
import { requireRole } from "../middleware/requireRole.js";
import { validate } from "../middleware/validate.js";
import {
	agentManageProfileSchema,
	agentProfileCreateSchema,
	agentProfilePatchSchema,
} from "../schemas/agentProfileSchemas.js";

const router = Router();

router.use(requireRole(["agent"]));

// GET /agent/profile - get own profile
router.get("/profile", getAgentProfile);

// POST /agent/profile - create own profile
router.post("/profile", validate(agentProfileCreateSchema), createAgentProfile);

// PATCH /agent/profile - update own profile
router.patch("/profile", validate(agentProfilePatchSchema), updateAgentProfile);

// PATCH /agent/profile/manage - manage own user + agent profile
router.patch("/profile/manage", validate(agentManageProfileSchema), updateAgentProfile);

export default router;
