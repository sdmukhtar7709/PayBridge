import { Router } from "express";
import { handleSignup, handleLogin } from "../controllers/authController.js";
import { validate } from "../middleware/validate.js";
import { signupSchema, loginSchema } from "../schemas/authSchemas.js";

const router = Router();

router.post("/signup", validate(signupSchema), handleSignup);
router.post("/login", validate(loginSchema), handleLogin);

export default router;
