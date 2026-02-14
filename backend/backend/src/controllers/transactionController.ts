import prisma from "../lib/prisma.js";
import { Request, Response } from "express";
import { AuthRequest } from "../middleware/auth.js";
import { sendOtpSms } from "../lib/sms.js"; // Make sure you have this utility!
import { sendOtpEmail } from "../lib/email.js";

// Extend Express Request interface to include 'user'
declare global {
  namespace Express {
    interface User {
      id: string;
      // add other user properties if needed
    }
    interface Request {
      user: User;
    }
  }
}

/**
 * POST /transactions/request
 * User requests cash from an agent. Generates OTP with expiry, sends SMS if phone present.
 */
export async function createTransaction(req: Request, res: Response) {
  const { agentId, amount } = req.body;
  const userId = req.user.id; // <-- Assumes requireAuth middleware sets req.user

  // Ensure agent exists, is verified, and not banned
  const agent = await prisma.agentProfile.findFirst({ where: { userId: agentId } });
  if (!agent || !agent.isVerified || agent.isBanned) {
    return res.status(400).json({ error: "Agent not available" });
  }

  // Generate 6-digit OTP and expiry (10 minutes)
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  const otpExpiry = new Date(Date.now() + 10 * 60 * 1000); // 10 min from now

  const txn = await prisma.agentTransaction.create({
    data: {
      status: "pending",
      amount,
      userId,
      agentId,
      otp,
      otpExpires: otpExpiry,
    }
  });

  // Find user with phone number for SMS
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { phone: true, email: true }
  });
  if (user && user.phone) {
    try {
      await sendOtpSms(user.phone, otp, txn.id);
    } catch (err) {
      // Log SMS error, do not fail transaction for user
      console.error("Failed to send OTP SMS:", err);
    }
  }
  if (user && user.email) {
    await sendOtpEmail(user.email, otp, txn.id);
  }
  // Log OTP for server-side debugging (never send real OTP to client!)
  console.log(`OTP for transaction ${txn.id}: ${otp} (expires ${otpExpiry.toISOString()})`);

  res.json({
    id: txn.id,
    status: txn.status,
    otp: "SENT" // Never send real OTP to client!
  });
}

/**
 * POST /transactions/confirm
 * Agent (or user) confirms transaction by OTP.
 */
export async function confirmTransaction(req: AuthRequest, res: Response) {
  const { transactionId, otp } = req.body;

  // Find the transaction
  const txn = await prisma.agentTransaction.findUnique({
    where: { id: transactionId },
    select: {
      id: true,
      status: true,
      amount: true,
      userId: true,
      agentId: true,
      otp: true,
      completedAt: true,
      otpExpires: true // Ensure otpExpires is selected
    }
  });
  if (!txn) return res.status(404).json({ error: "Transaction not found" });
  if (txn.status !== "pending") return res.status(400).json({ error: "Transaction already completed or cancelled" });
  if (txn.otpExpires && new Date() > txn.otpExpires) return res.status(400).json({ error: "OTP expired" });

  // AGENT MUST MATCH. If you want user to confirm, change to: txn.userId !== req.user.id
  if (txn.agentId !== req.user.id) return res.status(403).json({ error: "You are not the assigned agent" });

  if (txn.otp !== otp) return res.status(400).json({ error: "Invalid OTP" });

  // TODO: Move funds here (decrement agent's cash limit if needed, increment user's balance etc.)

  // Mark transaction as completed
  const updated = await prisma.agentTransaction.update({
    where: { id: transactionId },
    data: {
      status: "confirmed",
      completedAt: new Date(),
    }
  });

  res.json({
    id: updated.id,
    status: updated.status,
    completedAt: updated.completedAt,
  });
}