import prisma from "../lib/prisma.js";
import type { AdminAgentUpdateInput } from "../schemas/adminAgentSchemas.js";

export type AgentModerationStatus = "pending" | "verified" | "unverified" | "banned";
export type AdminModerationAction = "verify" | "unverify" | "ban" | "unban";

export class AdminModerationError extends Error {
  statusCode: number;

  constructor(message: string, statusCode = 400) {
    super(message);
    this.name = "AdminModerationError";
    this.statusCode = statusCode;
  }
}

function deriveStatusFromFlags(isVerified: boolean, isBanned: boolean): AgentModerationStatus {
  if (isBanned) return "banned";
  if (isVerified) return "verified";
  return "pending";
}

function flagsFromStatus(status: AgentModerationStatus) {
  return {
    isVerified: status === "verified",
    isBanned: status === "banned",
  };
}

async function getAgentOrThrow(id: string) {
  const agent = await prisma.agentProfile.findUnique({ where: { id } });
  if (!agent) {
    throw new AdminModerationError("Agent not found", 404);
  }
  return agent;
}

async function persistStatus(id: string, status: AgentModerationStatus, currentAvailability: boolean) {
  const normalizedFlags = flagsFromStatus(status);
  await prisma.agentProfile.update({
    where: { id },
    data: {
      status,
      isVerified: normalizedFlags.isVerified,
      isBanned: normalizedFlags.isBanned,
      available: status === "banned" ? false : currentAvailability,
    },
  });
}

export async function listAdminAgents() {
  const agents = await prisma.agentProfile.findMany({
    select: {
      id: true,
      locationName: true,
      city: true,
      latitude: true,
      longitude: true,
      available: true,
      cashLimit: true,
      createdAt: true,
      updatedAt: true,
      status: true,
      isVerified: true,
      isBanned: true,
      user: {
        select: {
          id: true,
          name: true,
          firstName: true,
          lastName: true,
          email: true,
          phone: true,
          gender: true,
          maritalStatus: true,
          age: true,
          address: true,
          profileImage: true,
        },
      },
    },
    orderBy: [{ createdAt: "desc" }],
  });

  return agents.map((agent) => {
    const firstName = agent.user.firstName?.trim() ?? "";
    const lastName = agent.user.lastName?.trim() ?? "";
    const fullName = [firstName, lastName].filter(Boolean).join(" ").trim();

    return {
      ...agent,
      fullName,
      user: {
        ...agent.user,
        fullName,
      },
    };
  });
}

export async function updateAgentModerationGeneric(id: string, body: AdminAgentUpdateInput) {
  const agent = await getAgentOrThrow(id);

  const computedStatus: AgentModerationStatus = body.status
    ? body.status
    : deriveStatusFromFlags(
        body.isVerified ?? agent.isVerified,
        body.isBanned ?? agent.isBanned
      );

  await persistStatus(id, computedStatus, agent.available);

  return {
    message: "Agent moderation updated successfully",
    status: computedStatus,
  };
}

export async function moderateAgentByAction(id: string, action: AdminModerationAction) {
  const agent = await getAgentOrThrow(id);

  switch (action) {
    case "verify": {
      if (agent.status === "banned") {
        throw new AdminModerationError("Cannot verify a banned agent without unbanning first", 409);
      }
      if (agent.status === "verified") {
        throw new AdminModerationError("Agent is already verified", 409);
      }

      await persistStatus(id, "verified", agent.available);
      return { message: "Agent verified successfully", status: "verified" as const };
    }

    case "unverify": {
      if (agent.status !== "verified") {
        throw new AdminModerationError("Only verified agents can be unverified", 409);
      }

      await persistStatus(id, "unverified", agent.available);
      return { message: "Agent unverified successfully", status: "unverified" as const };
    }

    case "ban": {
      if (agent.status === "banned") {
        throw new AdminModerationError("Agent is already banned", 409);
      }

      await persistStatus(id, "banned", agent.available);
      return { message: "Agent banned successfully", status: "banned" as const };
    }

    case "unban": {
      if (agent.status !== "banned") {
        throw new AdminModerationError("Cannot unban an agent that is not banned", 409);
      }

      await persistStatus(id, "unverified", agent.available);
      return { message: "Agent unbanned successfully", status: "unverified" as const };
    }

    default:
      throw new AdminModerationError("Unsupported moderation action", 400);
  }
}

type AdminTransactionListInput = {
  status?: "pending" | "approved" | "confirmed" | "cancelled" | "archived";
  from?: string;
  to?: string;
  search?: string;
  limit: number;
};

function buildFullName(firstName?: string | null, lastName?: string | null) {
  return [firstName?.trim(), lastName?.trim()].filter(Boolean).join(" ").trim();
}

export async function listAdminTransactions(input: AdminTransactionListInput) {
  const where: {
    status?: string;
    createdAt?: {
      gte?: Date;
      lte?: Date;
    };
  } = {};

  if (input.status) {
    where.status = input.status;
  }

  if (input.from) {
    where.createdAt = {
      ...(where.createdAt ?? {}),
      gte: new Date(input.from),
    };
  }

  if (input.to) {
    where.createdAt = {
      ...(where.createdAt ?? {}),
      lte: new Date(input.to),
    };
  }

  const transactions = await prisma.agentTransaction.findMany({
    where,
    orderBy: { createdAt: "desc" },
    take: input.limit,
    select: {
      id: true,
      userId: true,
      agentId: true,
      amount: true,
      status: true,
      createdAt: true,
    },
  });

  const userIds = Array.from(new Set(transactions.map((item) => item.userId)));
  const agentIds = Array.from(new Set(transactions.map((item) => item.agentId)));

  const [users, agentProfiles] = await Promise.all([
    prisma.user.findMany({
      where: { id: { in: userIds } },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        name: true,
        email: true,
        phone: true,
      },
    }),
    prisma.agentProfile.findMany({
      where: { id: { in: agentIds } },
      select: {
        id: true,
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            name: true,
            email: true,
            phone: true,
          },
        },
      },
    }),
  ]);

  const userMap = new Map(
    users.map((user) => {
      const fullName = buildFullName(user.firstName, user.lastName) || user.name || "Unknown User";
      return [
        user.id,
        {
          id: user.id,
          name: fullName,
          email: user.email ?? "-",
          phone: user.phone ?? "-",
        },
      ];
    })
  );

  const agentMap = new Map(
    agentProfiles.map((profile) => {
      const profileUser = profile.user;
      const fullName =
        buildFullName(profileUser.firstName, profileUser.lastName) ||
        profileUser.name ||
        "Unknown Agent";
      return [
        profile.id,
        {
          id: profile.id,
          name: fullName,
          email: profileUser.email ?? "-",
          phone: profileUser.phone ?? "-",
          userId: profileUser.id,
        },
      ];
    })
  );

  const items = transactions.map((item) => {
    const user = userMap.get(item.userId) ?? {
      id: item.userId,
      name: "Unknown User",
      email: "-",
      phone: "-",
    };

    const agent = agentMap.get(item.agentId) ?? {
      id: item.agentId,
      userId: "-",
      name: "Unknown Agent",
      email: "-",
      phone: "-",
    };

    return {
      id: item.id,
      amount: item.amount,
      type: "cash_request",
      status: item.status,
      date: item.createdAt,
      user,
      agent,
    };
  });

  const search = (input.search ?? "").trim().toLowerCase();
  const filtered =
    !search
      ? items
      : items.filter((item) => {
          const searchPool = [item.user.name, item.user.phone, item.agent.name, item.agent.phone]
            .join(" ")
            .toLowerCase();
          return searchPool.includes(search);
        });

  return { items: filtered, total: filtered.length };
}

export async function getAdminTransactionDetails(id: string) {
  const tx = await prisma.agentTransaction.findUnique({
    where: { id },
    select: {
      id: true,
      amount: true,
      status: true,
      createdAt: true,
      updatedAt: true,
      approvedAt: true,
      completedAt: true,
      userConfirmedAt: true,
      agentConfirmedAt: true,
      userRating: true,
      userRatingComment: true,
      ratedAt: true,
      requestOtp: true,
      userConfirmOtp: true,
      agentConfirmOtp: true,
      userId: true,
      agentId: true,
      requestOtpExpires: true,
      confirmOtpExpires: true,
    },
  });

  if (!tx) {
    throw new AdminModerationError("Transaction not found", 404);
  }

  const [user, agentProfile] = await Promise.all([
    prisma.user.findUnique({
      where: { id: tx.userId },
      select: {
        id: true,
        name: true,
        firstName: true,
        lastName: true,
        phone: true,
        email: true,
        address: true,
        profileImage: true,
      },
    }),
    prisma.agentProfile.findUnique({
      where: { id: tx.agentId },
      select: {
        id: true,
        status: true,
        isVerified: true,
        isBanned: true,
        available: true,
        ratingSum: true,
        ratingCount: true,
        locationName: true,
        city: true,
        latitude: true,
        longitude: true,
        user: {
          select: {
            id: true,
            name: true,
            firstName: true,
            lastName: true,
            phone: true,
            email: true,
            address: true,
            profileImage: true,
          },
        },
      },
    }),
  ]);

  const userName = user
    ? buildFullName(user.firstName, user.lastName) || user.name || "Unknown User"
    : "Unknown User";

  const agentName = agentProfile
    ? buildFullName(agentProfile.user.firstName, agentProfile.user.lastName) ||
      agentProfile.user.name ||
      "Unknown Agent"
    : "Unknown Agent";

  const userConfirmed = Boolean(tx.userConfirmedAt);
  const agentConfirmed = Boolean(tx.agentConfirmedAt);
  const agentRatingCount = Number(agentProfile?.ratingCount ?? 0);
  const agentRatingAverage =
    agentRatingCount > 0 ? Number(agentProfile?.ratingSum ?? 0) / agentRatingCount : null;

  return {
    id: tx.id,
    amount: tx.amount,
    type: "cash_request",
    status: tx.status,
    date: tx.createdAt,
    timestamps: {
      createdAt: tx.createdAt,
      updatedAt: tx.updatedAt,
      approvedAt: tx.approvedAt,
      completedAt: tx.completedAt,
    },
    rating: {
      value: tx.userRating,
      comment: tx.userRatingComment,
      ratedAt: tx.ratedAt,
      agentAverage: agentRatingAverage,
      agentCount: agentRatingCount,
    },
    user: {
      id: user?.id ?? tx.userId,
      name: userName,
      phone: user?.phone ?? "-",
      email: user?.email ?? "-",
      address: user?.address ?? "-",
      profileImage: user?.profileImage ?? "-",
    },
    agent: {
      id: agentProfile?.id ?? tx.agentId,
      name: agentName,
      phone: agentProfile?.user.phone ?? "-",
      email: agentProfile?.user.email ?? "-",
      address: agentProfile?.user.address ?? "-",
      profileImage: agentProfile?.user.profileImage ?? "-",
      status: agentProfile?.status ?? "pending",
      isVerified: Boolean(agentProfile?.isVerified),
      isBanned: Boolean(agentProfile?.isBanned),
      available: Boolean(agentProfile?.available),
      location: {
        locationName: agentProfile?.locationName ?? "-",
        city: agentProfile?.city ?? "-",
        latitude: agentProfile?.latitude ?? null,
        longitude: agentProfile?.longitude ?? null,
      },
    },
    verification: {
      otpVerified: userConfirmed && agentConfirmed,
      confirmations: {
        userConfirmed,
        agentConfirmed,
      },
      timestamps: {
        approvedAt: tx.approvedAt,
        userConfirmedAt: tx.userConfirmedAt,
        agentConfirmedAt: tx.agentConfirmedAt,
        completedAt: tx.completedAt,
      },
      expiry: {
        requestOtpExpires: tx.requestOtpExpires,
        confirmOtpExpires: tx.confirmOtpExpires,
      },
      otpPresence: {
        requestOtp: Boolean(tx.requestOtp),
        userConfirmOtp: Boolean(tx.userConfirmOtp),
        agentConfirmOtp: Boolean(tx.agentConfirmOtp),
      },
    },
  };
}

export async function getAdminReports(days: number) {
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);

  const [
    totalTransactions,
    sumResult,
    successfulTransactions,
    ongoingRequests,
    todayTransactions,
    todayVolumeResult,
    todaySuccessfulTransactions,
  ] = await Promise.all([
    prisma.agentTransaction.count(),
    prisma.agentTransaction.aggregate({
      _sum: { amount: true },
    }),
    prisma.agentTransaction.count({
      where: { status: "confirmed" },
    }),
    prisma.agentTransaction.count({
      where: {
        status: { in: ["pending", "approved"] },
      },
    }),
    prisma.agentTransaction.count({
      where: {
        createdAt: { gte: todayStart },
      },
    }),
    prisma.agentTransaction.aggregate({
      where: {
        createdAt: { gte: todayStart },
      },
      _sum: { amount: true },
    }),
    prisma.agentTransaction.count({
      where: {
        status: "confirmed",
        createdAt: { gte: todayStart },
      },
    }),
  ]);

  const now = new Date();
  const from = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
  const dailyRows = await prisma.agentTransaction.findMany({
    where: { createdAt: { gte: from } },
    select: { createdAt: true },
    orderBy: { createdAt: "asc" },
  });

  const dayMap = new Map<string, number>();
  for (let i = days - 1; i >= 0; i -= 1) {
    const date = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
    const key = date.toISOString().slice(0, 10);
    dayMap.set(key, 0);
  }

  dailyRows.forEach((row) => {
    const key = row.createdAt.toISOString().slice(0, 10);
    if (dayMap.has(key)) {
      dayMap.set(key, (dayMap.get(key) ?? 0) + 1);
    }
  });

  const transactionsPerDay = Array.from(dayMap.entries()).map(([date, count]) => ({
    date,
    count,
  }));

  const totalVolume = Number(sumResult._sum.amount ?? 0);
  const successRate = totalTransactions > 0 ? (successfulTransactions / totalTransactions) * 100 : 0;
  const todayVolume = Number(todayVolumeResult._sum.amount ?? 0);
  const todaySuccessRate = todayTransactions > 0 ? (todaySuccessfulTransactions / todayTransactions) * 100 : 0;

  return {
    totalTransactions,
    totalVolume,
    successRate,
    ongoingRequests,
    todaySnapshot: {
      transactions: todayTransactions,
      totalVolume: todayVolume,
      successRate: todaySuccessRate,
    },
    transactionsPerDay,
  };
}
