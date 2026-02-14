import { Router } from "express";

const router = Router();

router.get("/", (_req, res) => {
  res.json({
    name: "cash-platform",
    version: process.env.npm_package_version ?? "0.0.0",
    gitSha: process.env.GIT_SHA ?? "unknown",
    gitBranch: process.env.GIT_BRANCH ?? "unknown",
    buildTime: process.env.BUILD_TIME ?? "unknown",
  });
});

export default router;
