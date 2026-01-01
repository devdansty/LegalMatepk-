// backend/server.js
import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import cookieParser from "cookie-parser";
import chatbotModule from "./src/modules/chatbot/index.js";

dotenv.config();

const app = express();

/* -------------------- Middlewares -------------------- */
app.use(express.json({ limit: "5mb" }));
app.use(cookieParser());

app.use(
    cors({
        origin: process.env.FRONTEND_ORIGIN || true,
        credentials: true,
    })
);

/* -------------------- Routes -------------------- */
// Chatbot API → forwards request to Python service
app.use("/api/chatbot", chatbotModule);

// // Health check
// app.get("/health", (req, res) => {
//     res.json({ ok: true, status: "Backend running" });
// });

/* -------------------- Server -------------------- */
const PORT = process.env.PORT || 3000;
console.log("PYTHON_API_URL =", process.env.PYTHON_API_URL);

app.listen(PORT, () => {
    console.log(`🚀 Backend server running on port ${PORT}`);
    console.log(`🧠 Python API URL: ${process.env.PYTHON_API_URL}`);
});