import crypto from "crypto";
import argon2 from "argon2";
import jwt from "jsonwebtoken";
import Session from "./session.model.js";
import User from "../users/user.model.js";
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

export const refreshAccessToken = async (req, res) => {
  try {
    const token = req.cookies.refresh_token;
    if (!token) return res.status(401).json({ error: "Missing refresh token" });

    // Find candidate sessions which are not revoked and not expired.
    const candidates = await Session.find({
      revoked: false,
      expiresAt: { $gt: new Date() },
    });

    if (!candidates || candidates.length === 0)
      return res.status(401).json({ error: "Invalid session" });

    // We must find the session where the stored hash matches the provided token
    let matchedSession = null;
    for (const s of candidates) {
      try {
        const valid = await argon2.verify(s.refreshTokenHash, token);
        if (valid) {
          matchedSession = s;
          break;
        }
      } catch (e) {
        // ignore verify errors for this candidate and continue
      }
    }

    if (!matchedSession) return res.status(401).json({ error: "Invalid refresh token" });

    // Ensure user exists (account might have been deleted)
    if (!matchedSession.user) return res.status(401).json({ error: "User account no longer exists" });

    // Create a new access token containing the session id (sid)
    const newAccessToken = generateAccessToken(matchedSession.user.toString(), matchedSession._id.toString());
    res.json({ accessToken: newAccessToken });
  } catch (err) {
    console.error("refreshAccessToken error:", err);
    res.status(401).json({ error: "Failed to refresh token" });
  }
};

// ----------------- Logout (revoke session) -----------------
export const logout = async (req, res) => {
  try {
    // middleware verifySession ensures req.session exists
    if (req.session) {
      req.session.revoked = true;
      await req.session.save();
    } else if (req.sessionId) {
      await Session.findByIdAndUpdate(req.sessionId, { revoked: true });
    }

    res.clearCookie("refresh_token", { path: "/api/sessions/refresh" });
    return res.json({ ok: true, message: "Logged out successfully" });
  } catch (err) {
    console.error("logout error:", err);
    return res.status(500).json({ error: "Server error during logout" });
  }
};
export const listSessions = async (req, res) => {
  try {
    const userId = req.user?.id || req.user?._id;
    const sessions = await Session.find({ user: userId, revoked: false })
      .select("_id ip userAgent createdAt expiresAt");

    res.json(sessions);
  } catch (err) {
    console.error("listSessions error:", err);
    res.status(500).json({ error: "Server error" });
  }
};