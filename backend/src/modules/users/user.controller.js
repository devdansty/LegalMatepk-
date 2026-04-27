import crypto from "crypto";
import jwt from "jsonwebtoken";
import argon2 from "argon2";
import { validationResult } from "express-validator";
import validator from "validator";

import User from "./user.model.js";
import Session from "../sessions/session.model.js";
import { sendOtpEmail } from "../../shared/services/email.service.js";
import { OAuth2Client } from "google-auth-library";

const googleOAuthClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);
// ---------- JWT Helper ----------
const signJwt = (userId, sessionId) => {
  const payload = { sub: userId };
  if (sessionId) payload.sid = sessionId;
  return jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXP || '15m' });
};

const OTP_EXPIRY_MS = 10 * 60 * 1000;

const hashOtp = (otp) => {
  return crypto.createHash('sha256').update(otp).digest('hex');
};

const generateOtp = () => {
  return crypto.randomInt(100000, 1000000).toString();
};

const setAndSendEmailOtp = async (user) => {
  const otp = generateOtp();
  user.email_otp_hash = hashOtp(otp);
  user.email_otp_expires_at = new Date(Date.now() + OTP_EXPIRY_MS);
  user.email_otp_attempts = 0;
  await user.save();

  const sent = await sendOtpEmail({ to: user.email, otp });
  if (!sent) {
    // console.log(`[OTP_DEV] Email OTP for ${user.email}: ${otp}`);
  }

  return sent;
};

// Named export so other modules (e.g. lawyer controller) can reuse the same OTP flow
export { setAndSendEmailOtp };

// ---------- Session Helper ----------
const createSession = async (userId, req, res, isGuest = false) => {
  const refreshToken = crypto.randomBytes(64).toString('hex');
  const refreshTokenHash = await argon2.hash(refreshToken);
  const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30); // 30 days

  const sessionData = {
    user: userId,
    refreshTokenHash,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    expiresAt,
  };

  // Set guest call limit for guest users (5 API calls including chats)
  if (isGuest) {
    sessionData.guest_api_calls = 0;
    sessionData.guest_call_limit = 5;
  }

  const session = await Session.create(sessionData);

  // Create JWT with session ID
  const accessToken = signJwt(userId, session._id.toString());

  // Send refresh token as HTTP-only cookie
  res.cookie('refresh_token', refreshToken, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    path: '/api/sessions/refresh',
    expires: expiresAt,
  });

  return { accessToken, sessionId: session._id.toString() };
};

// ---------- Signup ----------
const signup = async (req, res) => {
  try {
    const errs = validationResult(req);
    if (!errs.isEmpty()) {
      const errorMsg = errs.array()[0]?.msg || 'Validation error';
      return res.status(400).json({ error: errorMsg });
    }

   const { email, password, display_name, username, preferred_language, phone, role } = req.body;
    
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }
    
    if (!validator.isEmail(email)) return res.status(400).json({ error: 'Invalid email' });

    const exists = await User.findOne({ email: email.toLowerCase() });
    if (exists) return res.status(409).json({ error: 'Email already in use' });

    const hash = await argon2.hash(password, { type: argon2.argon2id });

    const user = new User({
      email: email.toLowerCase(),
      password_hash: hash,
      username: username || undefined,
      phone: phone || null, 
      profile: { display_name: display_name || "" },
      preferred_language: preferred_language || 'ur',
      consent: { tos_accepted: true, tos_accepted_at: new Date() },
      is_guest: false,
      role: role === "lawyer" ? "lawyer" : "citizen"
    });

    await user.save();

    await setAndSendEmailOtp(user);

    res.status(201).json({ 
      user: { id: user._id, email: user.email, is_guest: user.is_guest },
      requires_email_verification: true,
      message: 'Signup successful. Verify OTP sent to email.'
    });
  } catch (err) {
    console.error('[SIGNUP_ERROR]', err.message);
    res.status(500).json({ error: err.message || 'Server error' });
  }
};

// ---------- Signin with session ----------
const signin = async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Missing credentials' });

    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) return res.status(401).json({ error: 'Invalid credentials' });

    const match = await argon2.verify(user.password_hash, password);
    if (!match) return res.status(401).json({ error: 'Invalid credentials' });

    if (!user.email_verified) {
      await setAndSendEmailOtp(user);
      return res.status(403).json({
        error: 'Email not verified',
        code: 'EMAIL_NOT_VERIFIED',
        email: user.email,
        message: 'Please verify OTP sent to your email before login.'
      });
    }

    user.last_login_at = new Date();
    await user.save();

    // Create session & set refresh token cookie
    const { accessToken, sessionId } = await createSession(user._id, req, res);

    res.json({
      user: { id: user._id, email: user.email, role: user.role, display_name: user.profile?.display_name || null, is_guest: user.is_guest },
      access_token: accessToken,
      session_id: sessionId
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};

const sendEmailOtp = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email || !validator.isEmail(email)) {
      return res.status(400).json({ error: 'Valid email is required' });
    }

    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) {
      return res.status(200).json({ ok: true, message: 'If account exists, OTP has been sent' });
    }

    if (user.email_verified) {
      return res.status(400).json({ error: 'Email already verified' });
    }

    await setAndSendEmailOtp(user);
    return res.status(200).json({ ok: true, message: 'OTP sent to email' });
  } catch (err) {
    console.error('[SEND_EMAIL_OTP_ERROR]', err.message);
    return res.status(500).json({ error: 'Server error' });
  }
};

const verifyEmailOtp = async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!email || !validator.isEmail(email) || !otp) {
      return res.status(400).json({ error: 'Email and OTP are required' });
    }

    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) {
      return res.status(400).json({ error: 'Invalid OTP' });
    }

    if (user.email_verified) {
      return res.status(200).json({ ok: true, message: 'Email already verified' });
    }

    if (!user.email_otp_hash || !user.email_otp_expires_at) {
      return res.status(400).json({ error: 'OTP not requested. Please request OTP again.' });
    }

    if (user.email_otp_expires_at < new Date()) {
      return res.status(400).json({ error: 'OTP expired. Please request a new OTP.' });
    }

    if ((user.email_otp_attempts || 0) >= 5) {
      return res.status(429).json({ error: 'Too many failed attempts. Request a new OTP.' });
    }

    const providedOtpHash = hashOtp(String(otp));
    if (providedOtpHash !== user.email_otp_hash) {
      user.email_otp_attempts = (user.email_otp_attempts || 0) + 1;
      await user.save();
      return res.status(400).json({ error: 'Invalid OTP' });
    }

    user.email_verified = true;
    user.email_verify_token = null;
    user.email_verify_expires_at = null;
    user.email_otp_hash = null;
    user.email_otp_expires_at = null;
    user.email_otp_attempts = 0;
    await user.save();

    return res.status(200).json({ ok: true, message: 'Email verified successfully' });
  } catch (err) {
    console.error('[VERIFY_EMAIL_OTP_ERROR]', err.message);
    return res.status(500).json({ error: 'Server error' });
  }
};

const devGuestLogin = async (req, res) => {
  try {
    // Generate unique guest user for each session
    const uniqueId = crypto.randomBytes(8).toString('hex');
    const guestEmail = `guest_${uniqueId}@legalmate.local`;

    const hash = await argon2.hash(
      crypto.randomBytes(24).toString('hex'),
      { type: argon2.argon2id }
    );

    const user = await User.create({
      email: guestEmail.toLowerCase(),
      password_hash: hash,
      phone: null,
      profile: { display_name: `Guest User` },
      preferred_language: 'ur',
      consent: { tos_accepted: true, tos_accepted_at: new Date() },
      role: 'guest',
      is_guest: true,
      status: 'active'
    });

    user.last_login_at = new Date();
    await user.save();

    // Create guest session with call limit
    const { accessToken, sessionId } = await createSession(user._id, req, res, true);

    return res.json({
      user: {
        id: user._id,
        email: user.email,
        role: user.role,
        is_guest: true,
        display_name: user.profile?.display_name || 'Guest User'
      },
      access_token: accessToken,
      session_id: sessionId,
      call_limit: 5,
      remaining_calls: 5
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to start guest session' });
  }
};

// ---------- Google OAuth ----------
const googleAuth = async (req, res) => {
  try {
    const { id_token } = req.body;
    // console.log('[GOOGLE_AUTH] Request received. id_token present:', !!id_token);
    if (!id_token) return res.status(400).json({ error: 'Google ID token is required' });

    const clientIdConfigured = process.env.GOOGLE_CLIENT_ID;
    // console.log('[GOOGLE_AUTH] GOOGLE_CLIENT_ID:', clientIdConfigured ? `${clientIdConfigured.slice(0, 25)}...` : 'NOT SET ❌');

    // Verify token with Google
    // console.log('[GOOGLE_AUTH] Verifying token with Google...');
    const ticket = await googleOAuthClient.verifyIdToken({
      idToken: id_token,
      audience: clientIdConfigured,
    });

    const payload = ticket.getPayload();
    const { email, name, given_name, family_name, picture, sub: googleId, aud } = payload;
    // console.log('[GOOGLE_AUTH] Token valid. Email:', email, '| Token audience:', aud);

    if (!email) return res.status(400).json({ error: 'Google account has no email' });

    const displayName = name || `${given_name || ''} ${family_name || ''}`.trim() || email.split('@')[0];

    // Check if user exists — do NOT auto-create
    let user = await User.findOne({ email: email.toLowerCase() });
    // console.log('[GOOGLE_AUTH] User in DB:', user ? `found (${user._id})` : 'not found');

    if (!user) {
      // Return a structured "not found" response so the client can offer registration
      return res.status(404).json({
        code: 'USER_NOT_FOUND',
        error: 'No account found for this Google address. Please create one.',
        google_display_name: displayName,
        google_email: email,
      });
    }

    // Existing user — link Google provider if not already linked
    const alreadyLinked = user.auth_providers?.some(p => p.provider === 'google');
    if (!alreadyLinked) {
      user.auth_providers = user.auth_providers || [];
      user.auth_providers.push({ provider: 'google', provider_id: googleId, linked_at: new Date() });
    }
    user.email_verified = true;
    user.last_login_at = new Date();
    await user.save();
    // console.log('[GOOGLE_AUTH] Existing user updated.');

    const { accessToken, sessionId } = await createSession(user._id, req, res);
    // console.log('[GOOGLE_AUTH] Session created. Sending response.');

    return res.json({
      user: {
        id: user._id,
        email: user.email,
        role: user.role,
        display_name: user.profile?.display_name || displayName,
        avatar_url: user.profile?.avatar_url || picture || null,
        is_guest: false,
      },
      access_token: accessToken,
      session_id: sessionId,
    });
  } catch (err) {
    console.error('[GOOGLE_AUTH_ERROR] Message:', err.message);
    // console.error('[GOOGLE_AUTH_ERROR] Stack:', err.stack);
    return res.status(401).json({ error: `Google authentication failed: ${err.message}` });
  }
};
// ---------- Profile routes ----------
const getProfile = async (req, res) => {
  const user = req.user;
  res.json({
    id: user._id ?? user._id,
    email: user.email,
    email_verified: user.email_verified,
    phone: user.phone,
    profile: user.profile,
    settings: user.settings,
    preferred_language: user.preferred_language,
    role: user.role,
    created_at: user.created_at,
    auth_providers: (user.auth_providers || []).map(p => ({ provider: p.provider })),
  });
};

const updateProfile = async (req, res) => {
  try {
    const { profile, settings, preferred_language } = req.body;
    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ error: 'User not found' });

    if (profile) user.profile = { ...user.profile.toObject(), ...profile };
    if (settings) user.settings = { ...user.settings, ...settings };
    if (preferred_language) user.preferred_language = preferred_language;

    await user.save();
    res.json({ ok: true, profile: user.profile });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
};
// ---------- Password management ----------
const changePassword = async (req, res) => {
  try {
    const { old_password, new_password } = req.body;
    if (!old_password || !new_password) return res.status(400).json({ error: 'Missing fields' });

    const user = await User.findById(req.user._id);
    const match = await argon2.verify(user.password_hash, old_password);
    if (!match) return res.status(401).json({ error: 'Old password incorrect' });

    user.password_hash = await argon2.hash(new_password);
    await user.save();
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
};

// ---------- OTP-based password change (no old password needed) ----------
const sendChangePasswordOtp = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ error: 'User not found' });

    // Google-only accounts cannot set a password
    const isGoogleOnly = user.auth_providers?.length > 0 &&
      user.auth_providers.every(p => p.provider === 'google') &&
      !user.password_hash;
    if (isGoogleOnly) {
      return res.status(400).json({ error: 'Google accounts cannot set a password here' });
    }

    await setAndSendEmailOtp(user);
    res.json({ ok: true, message: 'OTP sent to your email' });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
};

const changePasswordViaOtp = async (req, res) => {
  try {
    const { otp, new_password } = req.body;
    if (!otp || !new_password) return res.status(400).json({ error: 'OTP and new password are required' });
    if (new_password.length < 8) return res.status(400).json({ error: 'Password must be at least 8 characters' });

    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ error: 'User not found' });

    if (!user.email_otp_hash || !user.email_otp_expires_at) {
      return res.status(400).json({ error: 'No OTP requested. Please request one first.' });
    }
    if (user.email_otp_expires_at < new Date()) {
      return res.status(400).json({ error: 'OTP expired. Please request a new one.' });
    }
    if ((user.email_otp_attempts || 0) >= 5) {
      return res.status(429).json({ error: 'Too many failed attempts. Request a new OTP.' });
    }

    const providedOtpHash = hashOtp(String(otp));
    if (providedOtpHash !== user.email_otp_hash) {
      user.email_otp_attempts = (user.email_otp_attempts || 0) + 1;
      await user.save();
      return res.status(400).json({ error: 'Invalid OTP' });
    }

    // OTP valid — set new password and clear OTP fields
    user.password_hash = await argon2.hash(new_password, { type: argon2.argon2id });
    user.email_otp_hash = null;
    user.email_otp_expires_at = null;
    user.email_otp_attempts = 0;
    await user.save();

    res.json({ ok: true, message: 'Password changed successfully' });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
};

const requestPasswordReset = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Missing email' });

    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) return res.status(200).json({ ok: true }); // don't reveal existence

    const token = crypto.randomBytes(20).toString('hex');
    user.password_reset = {
      token,
      expires_at: new Date(Date.now() + 1000 * 60 * 60) // 1 hour
    };
    await user.save();

    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
};

const resetPassword = async (req, res) => {
  try {
    const { email, token, new_password } = req.body;
    if (!email || !token || !new_password) return res.status(400).json({ error: 'Missing fields' });

    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user || !user.password_reset?.token) return res.status(400).json({ error: 'Invalid token' });

    if (user.password_reset.expires_at < new Date()) return res.status(400).json({ error: 'Token expired' });
    if (user.password_reset.token !== token) return res.status(400).json({ error: 'Invalid token' });

    user.password_hash = await argon2.hash(new_password);
    user.password_reset = { token: null, expires_at: null };
    await user.save();
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
};

export default {
  devGuestLogin,
  signup,
  signin,
  sendEmailOtp,
  verifyEmailOtp,
  getProfile,
  updateProfile,
  changePassword,
  sendChangePasswordOtp,
  changePasswordViaOtp,
  requestPasswordReset,
  resetPassword,
  googleAuth,
  setAndSendEmailOtp,
};