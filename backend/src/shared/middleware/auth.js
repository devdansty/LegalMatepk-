import jwt from "jsonwebtoken";
import User from "../../modules/users/user.model.js";

export const requireAuth = (opts = {}) => {
  return async (req, res, next) => {
    try {
      const header = req.headers.authorization || "";
      if (!header.startsWith("Bearer "))
        return res.status(401).json({ error: "Unauthorized" });

      const token = header.split(" ")[1];
      const payload = jwt.verify(token, process.env.JWT_SECRET);

      const user = await User.findById(payload.sub).select("-password_hash");

      if (!user)
        return res.status(401).json({ error: "Invalid token (user not found)" });

      if (user.status !== "active")
        return res.status(403).json({ error: "Account not active" });

      req.user = user;
      next();
    } catch (err) {
      return res.status(401).json({ error: "Unauthorized", details: err.message });
    }
  };
};