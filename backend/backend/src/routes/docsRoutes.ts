import { Router } from "express";
import swaggerUi from "swagger-ui-express";
import fs from "fs";
import path from "path";
import YAML from "yaml";

const router = Router();

const openapiPath = path.resolve(process.cwd(), "src", "docs", "openapi.yaml");
const openapiDocument = YAML.parse(fs.readFileSync(openapiPath, "utf8"));

// Raw spec
router.get("/openapi.yaml", (_req, res) => {
  res.type("text/yaml").send(fs.readFileSync(openapiPath, "utf8"));
});

// Swagger UI with persisted auth token
router.use(
  "/",
  swaggerUi.serve,
  swaggerUi.setup(openapiDocument, {
    swaggerOptions: { persistAuthorization: true },
  })
);

export default router;
