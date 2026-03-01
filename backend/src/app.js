import express from "express";
import cookieParser from "cookie-parser";
import cors from "cors";

import chatbotModule from "./modules/chatbot/index.js";
import userRoutes from "./modules/users/user.routes.js";
import sessionRoutes from "./modules/sessions/session.routes.js";

const app = express();

app.use(express.json({ limit: "5mb" }));
app.use(cookieParser());
app.use(cors({
  origin: process.env.FRONTEND_ORIGIN || true,
  credentials: true
}));

app.use("/api/chatbot", chatbotModule);
app.use("/api/users", userRoutes);
app.use("/api/sessions", sessionRoutes);

app.get("/health", (req, res) => res.json({ ok: true }));

export default app;