file content paste each function one by one.
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import argon2 from 'argon2';
import { validationResult } from 'express-validator';
import User from '../models/User.js';
import Session from '../models/Session.js';
import validator from 'validator';

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
