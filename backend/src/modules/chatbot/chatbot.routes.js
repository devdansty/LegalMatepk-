import express from "express";
import multer from "multer";
import {
	handleChat,
	getChatHistory,
	clearChatHistory,
	createChatSession,
	getChatSessions,
	getChatSessionMessages,
	deleteChatSession,
} from "./chatbot.controller.js";
import { authIfPresent, requireAuth, requireNotGuest } from "../../shared/middleware/auth.js";
import { trackGuestCall } from "../../shared/middleware/guest.js";

const router = express.Router();

// Multer for optional image attachment on the chat endpoint (stored in memory)
const chatUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
  fileFilter: (_req, file, cb) => {
    const allowed = ["image/jpeg", "image/jpg", "image/png", "application/octet-stream"];
    const allowedExts = [".jpg", ".jpeg", ".png"];
    const ext = file.originalname.toLowerCase().match(/\.[^.]*$/)?.[0];
    if (allowed.includes(file.mimetype) && ext && allowedExts.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error(`Unsupported file type. Allowed: JPG, PNG (got ${file.mimetype})`));
    }
  },
});

// Chat endpoint: allows both authenticated and guest users
// Guest users are limited to 5 API calls per session
// Optional "image" field: if present, OCR extraction runs first
router.post("/", authIfPresent(), trackGuestCall(), chatUpload.single("image"), handleChat);

// Get chat history (authenticated users only)
router.get("/history", requireAuth(), getChatHistory);

// Clear chat history (authenticated users only)
router.delete("/history", requireAuth(), clearChatHistory);

// Chat session APIs (authenticated non-guest users only)
router.post("/sessions", requireAuth(), requireNotGuest(), createChatSession);
router.get("/sessions", requireAuth(), requireNotGuest(), getChatSessions);
router.get("/sessions/:chatId/messages", requireAuth(), requireNotGuest(), getChatSessionMessages);
router.delete("/sessions/:chatId", requireAuth(), requireNotGuest(), deleteChatSession);

export default router;