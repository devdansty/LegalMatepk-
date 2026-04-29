import express from "express";
import fileUpload from "express-fileupload";
import { requireAuth, authIfPresent, requireNotGuest } from "../../shared/middleware/auth.js";
import { authLimiter } from "../../shared/middleware/rateLimit.js";
import {
  devLawyerLogin,
  lawyerSignup,
  registerLawyer,
  getLawyers,
  getLawyerProfile,
  getMyLawyerProfile,
  updateMyLawyerProfile,
  sendRequest,
  getLawyerRequests,
  respondToRequest,
  getUserConnections
} from "./lawyer.controller.js";

const router = express.Router();

// File upload middleware for lawyer routes only
router.use(fileUpload({
  limits: { fileSize: 25 * 1024 * 1024 }, // 25 MB
  abortOnLimit: true,
  responseOnLimit: 'File size exceeds 25 MB limit',
}));

/**
 * PUBLIC ROUTES (No authentication required)
 */

/**
 * POST /api/lawyers/dev-login
 * Temporary test-only lawyer login using the first approved lawyer
 */
router.post("/dev-login", authLimiter, devLawyerLogin);

/**
 * POST /api/lawyers/signup
 * Lawyer registration - creates user account and lawyer profile
 * Requires: multipart/form-data with files and text fields
 */
router.post("/signup", authLimiter, lawyerSignup);

/**
 * GET /api/lawyers
 * Get list of all verified/approved lawyers
 */
router.get("/", getLawyers);

/**
 * GET /api/lawyers/profile/:lawyerId
 * Get one lawyer's public profile for user-side detail view
 */
router.get("/profile/:lawyerId", getLawyerProfile);

/**
 * AUTHENTICATED ROUTES (Require JWT token)
 */

/**
 * POST /api/lawyers/request
 * User sends connection request to a lawyer (authenticated users only, NOT guests)
 */
router.post("/request", requireAuth(), requireNotGuest(), sendRequest);

/**
 * GET /api/lawyers/requests/incoming
 * Lawyer sees incoming connection requests
 */
router.get("/requests/incoming", requireAuth(), getLawyerRequests);

/**
 * GET /api/lawyers/me/profile
 * Lawyer gets own profile details
 */
router.get("/me/profile", requireAuth(), getMyLawyerProfile);

/**
 * PUT /api/lawyers/me/profile
 * Lawyer updates profile details and visibility
 */
router.put("/me/profile", requireAuth(), updateMyLawyerProfile);

/**
 * POST /api/lawyers/requests/respond
 * Lawyer accepts or rejects connection request
 */
router.post("/requests/respond", requireAuth(), respondToRequest);

/**
 * GET /api/lawyers/my-connections
 * User sees their accepted lawyer connections
 */
router.get("/my-connections", requireAuth(), getUserConnections);

/**
 * POST /api/lawyers/register
 * Authenticated user registers as lawyer (for existing users)
 */
router.post("/register", requireAuth(), registerLawyer);

export default router;