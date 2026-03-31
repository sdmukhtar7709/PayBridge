import prisma from "../lib/prisma.js";

const userProfileSelect = {
  firstName: true,
  lastName: true,
  phone: true,
  gender: true,
  maritalStatus: true,
  age: true,
  address: true,
  city: true,
  profileImage: true,
} as const;

export type UserProfile = {
  firstName: string | null;
  lastName: string | null;
  phone: string | null;
  gender: string | null;
  maritalStatus: string | null;
  age: number | null;
  address: string | null;
  city: string | null;
  profileImage: string | null;
};

export type UpdateUserProfileInput = Partial<{
  firstName: string;
  lastName: string;
  phone: string;
  gender: string;
  maritalStatus: string;
  age: number;
  address: string;
  city: string;
  profileImage: string;
}>;

function normalizeOptionalString(value: string | undefined) {
  if (value === undefined) return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export async function getUserProfile(userId: string): Promise<UserProfile> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: userProfileSelect,
  });

  if (!user) {
    throw Object.assign(new Error("User not found"), { statusCode: 404 });
  }

  return user;
}

export async function updateUserProfile(
  userId: string,
  input: UpdateUserProfileInput
): Promise<UserProfile> {
  const existingUser = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      name: true,
      firstName: true,
      lastName: true,
    },
  });

  if (!existingUser) {
    throw Object.assign(new Error("User not found"), { statusCode: 404 });
  }

  const updateData: {
    firstName?: string | null;
    lastName?: string | null;
    phone?: string | null;
    gender?: string | null;
    maritalStatus?: string | null;
    age?: number | null;
    address?: string | null;
    city?: string | null;
    profileImage?: string | null;
    name?: string;
  } = {};

  const firstName = normalizeOptionalString(input.firstName);
  const lastName = normalizeOptionalString(input.lastName);
  const phone = normalizeOptionalString(input.phone);
  const gender = normalizeOptionalString(input.gender);
  const maritalStatus = normalizeOptionalString(input.maritalStatus);
  const address = normalizeOptionalString(input.address);
  const city = normalizeOptionalString(input.city);
  const profileImage = normalizeOptionalString(input.profileImage);

  if (firstName !== undefined) updateData.firstName = firstName;
  if (lastName !== undefined) updateData.lastName = lastName;
  if (phone !== undefined) updateData.phone = phone;
  if (gender !== undefined) updateData.gender = gender;
  if (maritalStatus !== undefined) updateData.maritalStatus = maritalStatus;
  if (address !== undefined) updateData.address = address;
  if (city !== undefined) updateData.city = city;
  if (profileImage !== undefined) updateData.profileImage = profileImage;

  if (input.age !== undefined) {
    updateData.age = Number.isFinite(input.age) ? input.age : null;
  }

  if (firstName !== undefined || lastName !== undefined) {
    const effectiveFirstName = firstName !== undefined ? firstName : existingUser.firstName;
    const effectiveLastName = lastName !== undefined ? lastName : existingUser.lastName;
    const fullName = [effectiveFirstName, effectiveLastName].filter(Boolean).join(" ").trim();
    updateData.name = fullName.length > 0 ? fullName : existingUser.name;
  }

  const updated = await prisma.user.update({
    where: { id: userId },
    data: updateData,
    select: userProfileSelect,
  });

  return updated;
}
