import rateLimit from "express-rate-limit";

/**
 * Authentication Rate Limiter
 * Limits failed authentication attempts to prevent brute-force attacks
 * 
 * Applied to:
 * - Login endpoints (signup, signin)
 * - Password reset endpoints
 * - OTP endpoints
 * 
 * Limits: 5 failed attempts per 15 minutes
 */
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts per windowMs for auth endpoints
  message: "Too many authentication attempts, please try again after 15 minutes.",
  standardHeaders: true, // Return rate limit info in RateLimit-* headers
  legacyHeaders: false, // Disable X-RateLimit-* headers
  skipSuccessfulRequests: true // Only count failed requests
});

/**
 * General Rate Limiter
 * Limits all requests to prevent spam and DDoS attacks
 * 
 * Limits: 100 requests per 15 minutes
 * Skips: Health check endpoint
 */
export const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // 100 requests per windowMs
  message: "Too many requests from this IP, please try again later.",
  standardHeaders: true, // Return rate limit info in RateLimit-* headers
  legacyHeaders: false, // Disable X-RateLimit-* headers
  skip: (req) => {
    // Skip rate limiting for health checks
    return req.path === "/health";
  }
});
