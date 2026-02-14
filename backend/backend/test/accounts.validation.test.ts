import { it, expect } from "vitest";
import request from "supertest";
import { app } from "../src/app.js";

it("returns 401 when unauthenticated on account create", async () => {
  const res = await request(app).post("/accounts").send({});
  expect(res.status).toBe(401);
});
