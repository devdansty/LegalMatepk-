// server.js
import express from "express";
import dotenv from "dotenv";
import mongoose from "mongoose";
import cors from "cors";
import cookieParser from "cookie-parser";
import chatbotModule from "./src/modules/chatbot/index.js";
import userRoutes from "./src/routes/users.js";
import sessionRoutes from "./src/routes/sessions.js";


dotenv.config();

const app = express();
app.use(express.json({ limit: "5mb" }));
app.use(cookieParser());
app.use(cors({
  origin: process.env.FRONTEND_ORIGIN || true,
  credentials: true
}));

const MONGO_URI = process.env.MONGO_URI;
mongoose.connect(MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log(`✅ Connected to MongoDB database: ${mongoose.connection.name}`))
  .catch(err => { console.error("MongoDB connection error:", err); process.exit(1); });

  
app.use("/api/chatbot", chatbotModule);
app.use("/api/users", userRoutes);
app.use("/api/sessions", sessionRoutes);

app.get("/health", (req, res) => res.json({ ok: true }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`🧠 Python API URL: ${process.env.PYTHON_API_URL}`);
});
