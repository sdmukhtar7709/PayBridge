import { Request, Response } from "express";
import { signup, login } from "../services/authService.js";

export async function handleSignup(req: Request, res: Response) {
  try {
    const result = await signup(req.body);
    res.status(201).json(result);
  } catch (err: any) {
    res.status(400).json({ error: err.message || "Signup failed" });
  }
}

export async function handleLogin(req: Request, res: Response) {
  try {
    const result = await login(req.body);
    res.status(200).json(result);
  } catch (err: any) {
    res.status(400).json({ error: err.message || "Login failed" });
  }
}
