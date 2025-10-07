import crypto from "crypto";
import argon2 from "argon2";
import jwt from "jsonwebtoken";
import Session from "../models/Session.js";
import User from "../models/User.js";
// sessionController.js (patches)

// ----------------- Helpers -----------------
const generateAccessToken = (userId, sessionId) => {
  // include session id (sid) so we can revoke that specific session later
  return jwt.sign({ sub: userId, sid: sessionId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXP || "15m",
  });
};

const generateRefreshToken = () => crypto.randomBytes(64).toString("hex");

// ----------------- Sign in / create session -----------------
export const createSession = async (userId, req, res) => {
  try {
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ error: "User not found" });

    const refreshToken = generateRefreshToken();
    const refreshTokenHash = await argon2.hash(refreshToken);

    const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30); // 30 days

    const session = await Session.create({
      user: user._id,
      refreshTokenHash,
      ip: req.ip,
      userAgent: req.get("User-Agent"),
      expiresAt,
    });

    // include session._id in the access token as sid
    const accessToken = generateAccessToken(user._id, session._id.toString());

    // Send refresh token cookie (HTTP-only)
    res.cookie("refresh_token", refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "strict",
      path: "/api/sessions/refresh",
      expires: expiresAt,
    });

    // Send access token + user data (and session id if you want)
    res.json({
      accessToken,
      user: {
        id: user._id,
        email: user.email,
        display_name: user.profile?.display_name || null,
      },
      // optional: include session id in response payload (not necessary if in token)
      sessionId: session._id,
    });
  } catch (err) {
    console.error("createSession error:", err);
    res.status(500).json({ error: "Server error" });
  }
};

/