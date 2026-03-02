import crypto from "crypto";
import jwt from "jsonwebtoken";
import argon2 from "argon2";
import { validationResult } from "express-validator";
import validator from "validator";

import User from "./user.model.js";
import Session from "../sessions/session.model.js";
// ---------- JWT Helper ----------
const signJwt = (userId) => {
  return jwt.sign({ sub: userId }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXP || '15m' });
};

// ---------- Session Helper ----------
const createSession = async (userId, req, res) => {
  const accessToken = signJwt(userId);

  const refreshToken = crypto.randomBytes(64).toString('hex');
  const refreshTokenHash = await argon2.hash(refreshToken);
  const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30); // 30 days
  const { role } = req.body;

  await Session.create({
    user: userId,
    refreshTokenHash,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    expiresAt,
  });

  // Send refresh token as HTTP-only cookie
  res.cookie('refresh_token', refreshToken, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    path: '/api/sessions/refresh',
    expires: expiresAt,
  });

  return accessToken;
};

// ---------- Signup ----------
const signup = async (req, res) => {
  try {
    const errs = validationResult(req);
    if (!errs.isEmpty()) return res.status(400).json({ errors: errs.array() });

   const { email, password, display_name, username, preferred_language, phone } = req.body;
    if (!validator.isEmail(email)) return res.status(400).json({ error: 'Invalid email' });

    const exists = await User.findOne({ email: email.toLowerCase() });
    if (exists) return res.status(409).json({ error: 'Email already in use' });

    const hash = await argon2.hash(password, { type: argon2.argon2id });

    const verifyToken = crypto.randomBytes(20).toString('hex');
    const verifyExpires = new Date(Date.now() + 1000 * 60 * 60 * 24); // 24h

    const user = new User({
      email: email.toLowerCase(),
      password_hash: hash,
      username: username || undefined,
      phone: phone || null, 
      profile: { display_name: display_name || "" },
      preferred_language: preferred_language || 'ur',
      email_verify_token: verifyToken,
      email_verify_expires_at: verifyExpires,
      consent: { tos_accepted: true, tos_accepted_at: new Date() },
      role: role === "lawyer" ? "lawyer" : "citizen"
    });

    await user.save();

    const token = signJwt(user._id);
    res.status(201).json({ user: { id: user._id, email: user.email }, access_token: token });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
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

    user.last_login_at = new Date();
    await user.save();

    // Create session & set refresh token cookie
    const accessToken = await createSession(user._id, req, res);

    res.json({
      user: { id: user._id, email: user.email, role: user.role, display_name: user.profile?.display_name || null },
      access_token: accessToken
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};
// ---------- Profile routes ----------
const getProfile = async (req, res) => {
  const user = req.user;
  res.json({
    id: user._id ?? user._id, // fallback in case of different naming
    email: user.email,
    email_verified: user.email_verified,
    phone: user.phone,
    profile: user.profile,
    settings: user.settings,
    preferred_language: user.preferred_language,
    role: user.role,
    created_at: user.created_at
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
  signup,
  signin,
  getProfile,
  updateProfile,
  changePassword,
  requestPasswordReset,
  resetPassword
};