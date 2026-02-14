import { z } from "zod";

export const authLoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

export const accountCreateSchema = z.object({
  name: z.string().trim().min(1),
  balance: z.coerce
    .number({ invalid_type_error: "balance must be a number" })
    .nonnegative(),
});

export const transactionCreateSchema = z
  .object({
    type: z.enum(["transfer", "debit", "credit"]),
    amount: z.coerce
      .number({ invalid_type_error: "amount must be a number" })
      .positive(),
    fromAccountId: z.string().uuid().optional(),
    toAccountId: z.string().uuid().optional(),
    categoryId: z.string().uuid().optional(),
    description: z.string().trim().max(200).optional(),
  })
  .superRefine((data, ctx) => {
    if (data.type === "transfer") {
      if (!data.fromAccountId) {
        ctx.addIssue({
          code: "custom",
          path: ["fromAccountId"],
          message: "fromAccountId required for transfer",
        });
      }
      if (!data.toAccountId) {
        ctx.addIssue({
          code: "custom",
          path: ["toAccountId"],
          message: "toAccountId required for transfer",
        });
      }
    }
  });

export const categoryCreateSchema = z.object({
  name: z.string().trim().min(1),
  description: z.string().trim().max(200).optional(),
});
