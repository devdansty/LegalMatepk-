// server.js
import express from "express";
import dotenv from "dotenv";
import mongoose from "mongoose";
import cors from "cors";
import cookieParser from "cookie-parser";
import axios from "axios";

// Modules
import chatbotModule from "./src/modules/chatbot/index.js";
import userRoutes from "./src/routes/users.js"; // your user routes
import sessionRoutes from "./src/routes/sessions.js";

dotenv.config();

const app = express();
app.use(express.json({ limit: "5mb" }));
app.use(cookieParser());
app.use(cors({
  origin: process.env.FRONTEND_ORIGIN || true,
  credentials: true
}));

// ---------- MongoDB connection ----------
const MONGO_URI = process.env.MONGO_URI;
mongoose.connect(MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log(`✅ Connected to MongoDB database: ${mongoose.connection.name}`))
  .catch(err => { console.error("MongoDB connection error:", err); process.exit(1); });

// ---------- Python client ----------
export const pythonClient = axios.create({
  baseURL: process.env.PYTHON_API_URL || "https://garnishable-shawna-automotive.ngrok-free.dev",
  timeout: 1000000000,
});

export const chatBotApi = async (message) => {
  try {
    const response = await pythonClient.post("/generate", { prompt: message });
    return response?.data?.response || null;
  } catch (err) {
    console.error("❌ Error calling Python API:", err?.message || err);
    throw new Error("Python service unavailable");
  }
};

// ---------- Mount routes ----------
app.use("/api/chatbot", chatbotModule);
app.use("/api/users", userRoutes);
app.use("/api/sessions", sessionRoutes);

// Optional AI test endpoint
app.post("/api/ai/generate", async (req, res) => {
  const { prompt } = req.body;
  if (!prompt) return res.status(400).json({ error: "Missing prompt" });
  try {
    const response = await chatBotApi(prompt);
    res.json({ response });
  } catch (err) {
    res.status(503).json({ error: "AI service unavailable" });
  }
});

// Health check
app.get("/health", (req, res) => res.json({ ok: true }));

// ---------- Start server ----------
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`🧠 Python API URL: ${process.env.PYTHON_API_URL}`);
});
