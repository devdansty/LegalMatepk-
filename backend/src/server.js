import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";
import mongoose from "mongoose";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, "../.env") });

// Import app AFTER dotenv is configured
const { default: app } = await import("./app.js");

const MONGO_URI = process.env.MONGO_URI;

mongoose.connect(MONGO_URI)
  .then(() => console.log(`✅ MongoDB: ${mongoose.connection.name}`))
  .catch(err => {
    console.error("MongoDB error:", err);
    process.exit(1);
  });

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`[SERVER_DEBUG] OCR_ALLOW_GUEST_TEST env value: "${process.env.OCR_ALLOW_GUEST_TEST}"`);
  console.log(`[SERVER_DEBUG] Type: ${typeof process.env.OCR_ALLOW_GUEST_TEST}`);
});