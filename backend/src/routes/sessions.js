import express from "express";
import { requireAuth } from "../middleware/auth.js";
import * as sessionCtrl from "../controllers/sessionController.js";

const router = express.Router();

// refresh access token
router.post("/refresh", sessionCtrl.refreshAccessToken);

// logout current session
router.post("/logout", requireAuth(), sessionCtrl.logout);

// list active sessions for user
router.get("/", requireAuth(), sessionCtrl.listSessions);

export default router;
