import { Router } from "express";
import {
	loginController,
	registerAdminController,
	registerController,
} from "../controllers/auth.controller.js";
import { validate } from "../../../middleware/validate.js";
import {
	adminRegisterSchema,
	loginSchema,
	registerSchema,
} from "../schemas/auth.schema.js";

const router = Router();

router.post("/register", validate(registerSchema), registerController);
router.post("/login", validate(loginSchema), loginController);
router.post(
	"/admin/register",
	validate(adminRegisterSchema),
	registerAdminController
);

export default router;
