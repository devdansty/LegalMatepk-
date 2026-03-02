import express from "express";
import { requireAuth } from "../../shared/middleware/auth.js";
import * as sessionCtrl from "./session.controller.js";

const router = express.Router();

// refresh access token
router.post("/refresh", sessionCtrl.refreshAccessToken);

// logout current session
router.post("/logout", requireAuth(), sessionCtrl.logout);

// list active sessions
router.get("/", requireAuth(), sessionCtrl.listSessions);

export default router;