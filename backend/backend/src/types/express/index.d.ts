import { Request } from "express";

export interface UserJwtPayload {
  id: string;
  email: string;
  role?: string;
  // Add other fields if your JWT/user includes them
}

export interface AuthRequest extends Request {
  user: UserJwtPayload;
}