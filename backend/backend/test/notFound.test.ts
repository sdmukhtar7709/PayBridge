import { describe, it, expect } from "vitest";
import request from "supertest";
import { app } from "../src/app.js";

describe("not found", () => {
  it("returns 404 for unknown route", async () => {
    const res = await request(app).get("/__missing__");
    expect(res.status).toBe(404);
  });
});
