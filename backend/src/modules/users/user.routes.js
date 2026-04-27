import express from "express";
import { body } from "express-validator";
import userCtrl from "./user.controller.js";
import { requireAuth } from "../../shared/middleware/auth.js";

const router = express.Router();

// Signup
router.post("/signup", [
  body("email").isEmail().withMessage("Invalid email address"),
  body("password").isLength({ min: 8 }).withMessage("Password must be at least 8 characters")
], userCtrl.signup);

// Temporary guest citizen login for testing
router.post("/dev-guest-login", userCtrl.devGuestLogin);

// Google OAuth
router.post("/google-auth", userCtrl.googleAuth);

// Signin
router.post("/signin", [
  body("email").isEmail(),
  body("password").exists()
], userCtrl.signin);

// Send OTP for email verification
router.post('/email-otp/send', [
  body('email').isEmail().withMessage('Invalid email address')
], userCtrl.sendEmailOtp);

// Verify email OTP
router.post('/email-otp/verify', [
  body('email').isEmail().withMessage('Invalid email address'),
  body('otp').isLength({ min: 4, max: 8 }).withMessage('Invalid OTP')
], userCtrl.verifyEmailOtp);

// Get profile
router.get("/me", requireAuth(), userCtrl.getProfile);

// Update profile
router.put("/me", requireAuth(), userCtrl.updateProfile);

// Change password (requires old password)
router.post("/change-password", requireAuth(), userCtrl.changePassword);

// OTP-based password change (step 1: send OTP to own email)
router.post("/send-change-password-otp", requireAuth(), userCtrl.sendChangePasswordOtp);

// OTP-based password change (step 2: verify OTP + set new password)
router.post("/change-password-otp", requireAuth(), userCtrl.changePasswordViaOtp);

// Password reset request
router.post("/password-reset/request", userCtrl.requestPasswordReset);

// Password reset confirm
router.post("/password-reset/confirm", userCtrl.resetPassword);

export default router;