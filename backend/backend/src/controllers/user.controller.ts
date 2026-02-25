import { Response } from "express";
import { AuthRequest } from "../middleware/auth.js";
import { getUserProfile, updateUserProfile } from "../services/user.service.js";

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

export async function getProfileController(req: AuthRequest, res: Response) {
  try {
    const profile = await getUserProfile(req.user.id);
    return res.status(200).json(profile);
  } catch (error) {
    return res.status(getStatusCode(error, 500)).json({
      error: getMessage(error, "Failed to fetch profile"),
    });
  }
}

export async function updateProfileController(req: AuthRequest, res: Response) {
  try {
    const profile = await updateUserProfile(req.user.id, req.body);
    return res.status(200).json(profile);
  } catch (error) {
    return res.status(getStatusCode(error, 400)).json({
      error: getMessage(error, "Failed to update profile"),
    });
  }
}
