import { it, expect, describe } from "vitest";
import request from "supertest";
import { app } from "../src/app.js";

const shouldSkip =
  process.env.SKIP_DB_TESTS === "1" || !process.env.DATABASE_URL;

if (shouldSkip) {
  describe.skip("auth login (db)", () => {
    it("skipped because DB not configured", () => {});
  });
} else {
  describe("auth login (db)", () => {
    const demoCreds = { email: "demo@example.com", password: "password123" };

    it("logs in seeded demo user", async () => {
      const res = await request(app).post("/auth/login").send(demoCreds);
      expect(res.status).toBe(200);
      const token = res.body?.token ?? res.body?.accessToken;
      expect(typeof token).toBe("string");
      expect(token.length).toBeGreaterThan(10);
    });
  });
}
