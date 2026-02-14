import { it, expect } from "vitest";
import request from "supertest";
import { app } from "../src/app.js";

const skip = !!process.env.SKIP_DB_TESTS;

(skip ? it.skip : it)("refresh rotates and revokes old token", async () => {
  const loginRes = await request(app)
    .post("/auth/login-with-refresh")
    .send({ email: "demo@example.com", password: "password123" });

  expect(loginRes.status).toBe(200);
  const oldRefresh = loginRes.body?.refreshToken;
  expect(oldRefresh).toBeDefined();

  const refreshRes = await request(app)
    .post("/auth/refresh")
    .send({ refreshToken: oldRefresh });

  expect(refreshRes.status).toBe(200);
  expect(refreshRes.body?.refreshToken).toBeDefined();
  expect(refreshRes.body?.accessToken).toBeDefined();
  expect(refreshRes.body.refreshToken).not.toBe(oldRefresh);

  // old refresh should now be invalid
  const second = await request(app)
    .post("/auth/refresh")
    .send({ refreshToken: oldRefresh });

  expect(second.status).toBe(401);
});
