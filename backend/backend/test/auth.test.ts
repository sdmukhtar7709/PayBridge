import { describe, it, expect } from "vitest";
import request from "supertest";
import { app } from "../src/app.js";

describe("auth/login validation", () => {
  it("returns 400 on invalid email", async () => {
    const res = await request(app)
      .post("/auth/login")
      .send({ email: "bad", password: "123" });

    expect(res.status).toBe(400);
    expect(res.body?.error?.code).toBe("VALIDATION_ERROR");
  });
});
