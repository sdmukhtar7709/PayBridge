import { Request, Response } from "express";
import { loginUser, registerUser } from "../services/auth.service.js";

function getStatusCode(error: unknown, fallback: number) {
  if (
    typeof error === "object" &&
    error !== null &&
    "statusCode" in error &&
    typeof (error as { statusCode?: unknown }).statusCode === "number"
  ) {
    return (error as { statusCode: number }).statusCode;
  }
  return fallback;
}

function getMessage(error: unknown, fallback: string) {
  if (
    typeof error === "object" &&
    error !== null &&
    "message" in error &&
    typeof (error as { message?: unknown }).message === "string"
  ) {
    return (error as { message: string }).message;
  }
  return fallback;
}

export async function registerController(req: Request, res: Response) {
  try {
    const payload = await registerUser(req.body);
    return res.status(201).json(payload);
  } catch (error) {
    return res.status(getStatusCode(error, 400)).json({ error: getMessage(error, "Registration failed") });
  }
}

export async function loginController(req: Request, res: Response) {
  try {
    const payload = await loginUser(req.body);
    return res.status(200).json(payload);
  } catch (error) {
    return res.status(getStatusCode(error, 401)).json({ error: getMessage(error, "Login failed") });
  }
}
