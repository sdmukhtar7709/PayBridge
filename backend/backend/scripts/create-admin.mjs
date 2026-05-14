import bcrypt from "bcrypt";
import { PrismaClient } from "@prisma/client";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const envPath = path.resolve(__dirname, "../.env");
dotenv.config({ path: envPath });

const prisma = new PrismaClient();
const email = "muktar@gmail.com";
const password = "muktar123";
const name = "Muktar";
const phone = null;

async function main() {
  const existing = await prisma.user.findUnique({ where: { email } });
  const passwordHash = await bcrypt.hash(password, 10);

  if (existing) {
    const updated = await prisma.user.update({
      where: { email },
      data: {
        passwordHash,
        name,
        phone,
        role: "admin",
      },
    });
    console.log(`Updated existing user to admin: ${updated.email} (role=${updated.role})`);
    return;
  }

  const user = await prisma.user.create({
    data: {
      email,
      passwordHash,
      name,
      phone,
      role: "admin",
    },
  });

  console.log(`Created admin user: ${user.email} (id=${user.id})`);
}

main()
  .catch((error) => {
    console.error("Failed to create admin user:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
