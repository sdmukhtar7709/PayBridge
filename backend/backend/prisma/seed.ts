import { PrismaClient, TransactionType } from "@prisma/client";
import bcrypt from "bcrypt";

const prisma = new PrismaClient();
const DEMO_EMAIL = "demo@example.com";
const DEMO_PASSWORD = "password123";
const DEMO_NAME = "Demo User";

async function main() {
  const passwordHash = await bcrypt.hash(DEMO_PASSWORD, 10);

  const user = await prisma.user.upsert({
    where: { email: DEMO_EMAIL },
    update: { passwordHash, name: DEMO_NAME, role: "user" },
    create: {
      email: DEMO_EMAIL,
      name: DEMO_NAME,
      passwordHash,
      role: "user",
    },
  });

  // Create a main account for the user (reuse user ID to keep seed idempotent/simple)
  const account = await prisma.account.upsert({
    where: { id: user.id },
    update: { name: "Main Account", balance: 1000 },
    create: {
      id: user.id,
      name: "Main Account",
      balance: 1000,
      userId: user.id,
    },
  });

  const incomeCat = await prisma.category.upsert({
    where: { userId_name_type: { userId: user.id, name: "Salary", type: TransactionType.INCOME } },
    update: {},
    create: { name: "Salary", type: TransactionType.INCOME, userId: user.id },
  });

  const expenseCat = await prisma.category.upsert({
    where: { userId_name_type: { userId: user.id, name: "Food", type: TransactionType.EXPENSE } },
    update: {},
    create: { name: "Food", type: TransactionType.EXPENSE, userId: user.id },
  });

  // Clear existing transactions for this account to keep seed predictable
  await prisma.transaction.deleteMany({ where: { accountId: account.id } });

  await prisma.transaction.createMany({
    data: [
      {
        type: TransactionType.INCOME,
        amount: 2000,
        description: "Salary",
        accountId: account.id,
        categoryId: incomeCat.id,
        occurredAt: new Date(),
      },
      {
        type: TransactionType.EXPENSE,
        amount: 50,
        description: "Groceries",
        accountId: account.id,
        categoryId: expenseCat.id,
        occurredAt: new Date(),
      },
    ],
  });
  // --- Seed admin user ---
const adminEmail = "admin@example.com";
const adminPassword = "admin123";
const adminPasswordHash = await bcrypt.hash(adminPassword, 10);

await prisma.user.upsert({
  where: { email: adminEmail },
  update: { passwordHash: adminPasswordHash, name: "Admin User", role: "admin" },
  create: {
    email: adminEmail,
    name: "Admin User",
    passwordHash: adminPasswordHash,
    role: "admin",
  },
});

  console.log("Seeded user/account/transactions:", {
    user: { id: user.id, email: user.email },
    account: { id: account.id, name: account.name },
    transactions: 2,
  });
}

main()
  .catch((e) => {
    console.error("Seed failed:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
