import jwt from "jsonwebtoken";
import User from "../../modules/users/user.model.js";
import Session from "../../modules/sessions/session.model.js";

export const requireAuth = (opts = {}) => {
  return async (req, res, next) => {
    try {
      const header = req.headers.authorization || "";
      if (!header.startsWith("Bearer "))
        return res.status(401).json({ error: "Unauthorized - missing or invalid auth header" });

      const token = header.split(" ")[1];
      const payload = jwt.verify(token, process.env.JWT_SECRET);

      const user = await User.findById(payload.sub).select("-password_hash");

      if (!user)
        return res.status(401).json({ error: "Invalid token (user not found)" });

      if (user.status !== "active")
        return res.status(403).json({ error: "Account not active" });

      // Validate session age (>15 days = force logout)
      if (payload.sid) {
        const session = await Session.findById(payload.sid);
        if (!session || session.revoked) {
          return res.status(401).json({ error: "Session expired or revoked" });
        }

        const sessionAge = Date.now() - session.createdAt.getTime();
        const maxSessionAge = 15 * 24 * 60 * 60 * 1000; // 15 days
        if (sessionAge > maxSessionAge) {
          session.revoked = true;
          await session.save();
          return res.status(401).json({ error: "Session expired - please login again" });
        }

        req.session = session;
      }

      req.user = user;
      next();
    } catch (err) {
      console.error('[AUTH_ERROR]', err.message);
      return res.status(401).json({ error: "Unauthorized", details: err.message });
    }
  };
};

/**
 * Ensure user is NOT a guest
 * Use after requireAuth middleware
 */
export const requireNotGuest = (opts = {}) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (req.user.is_guest || req.user.role === "guest") {
      return res.status(403).json({ error: "This feature is not available for guest users. Please sign in." });
    }

    next();
  };
};

/**
 * Optional auth - allows both authenticated and guest users
 * Attaches req.user if authenticated, continues without if not
 */
export const authIfPresent = (opts = {}) => {
  return async (req, res, next) => {
    try {
      const header = req.headers.authorization || "";
      if (!header.startsWith("Bearer ")) {
        // No token present - continue without authentication
        return next();
      }

      const token = header.split(" ")[1];
      const payload = jwt.verify(token, process.env.JWT_SECRET);

      const user = await User.findById(payload.sub).select("-password_hash");
      if (user && user.status === "active") {
        req.user = user;
        
        // Validate session age if sid present
        if (payload.sid) {
          const session = await Session.findById(payload.sid);
          if (session && !session.revoked) {
            const sessionAge = Date.now() - session.createdAt.getTime();
            const maxSessionAge = 15 * 24 * 60 * 60 * 1000;
            if (sessionAge <= maxSessionAge) {
              req.session = session;
            }
          }
        }
      }

      next();
    } catch (err) {
      // Token validation failed - continue without auth
      next();
    }
  };
};