// routes/users.js
import express from 'express';
import { body } from 'express-validator';
import userCtrl from '../controllers/userController.js';
import { requireAuth } from '../middleware/auth.js';

const router = express.Router();

// Signup
router.post('/signup', [
  body('email').isEmail(),
  body('password').isLength({ min: 8 })
], userCtrl.signup);

// Verify email
// router.post('/verify-email', userCtrl.verifyEmail);

// Signin
router.post('/signin', [
  body('email').isEmail(),
  body('password').exists()
], userCtrl.signin);

// Get profile
router.get('/me', requireAuth(), userCtrl.getProfile);

// Update profile
router.put('/me', requireAuth(), userCtrl.updateProfile);

// Change password
router.post('/change-password', requireAuth(), userCtrl.changePassword);

// Password reset request
router.post('/password-reset/request', userCtrl.requestPasswordReset);

// Password reset
router.post('/password-reset/confirm', userCtrl.resetPassword);

export default router;
