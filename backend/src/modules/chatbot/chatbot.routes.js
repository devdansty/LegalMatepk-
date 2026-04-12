import express from "express";
import { handleChat, getChatHistory, clearChatHistory } from "./chatbot.controller.js";
import { getTranslationStats, getFormattedStats } from "./chatbot.monitoring.js";
import { authIfPresent, requireAuth } from "../../shared/middleware/auth.js";
import { trackGuestCall } from "../../shared/middleware/guest.js";

const router = express.Router();

// Chat endpoint: allows both authenticated and guest users
// Guest users are limited to 5 API calls per session
router.post("/", authIfPresent(), trackGuestCall(), handleChat);

// Get chat history (authenticated users only)
router.get("/history", requireAuth(), getChatHistory);

// Clear chat history (authenticated users only)
router.delete("/history", requireAuth(), clearChatHistory);

// Monitoring endpoints (for debugging/logging)
router.get("/stats", getTranslationStats);
router.get("/stats/formatted", getFormattedStats);

export default router;