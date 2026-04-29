import express from "express";
import cookieParser from "cookie-parser";
import cors from "cors";
import helmet from "helmet";
import { generalLimiter } from "./shared/middleware/rateLimit.js";

import lawyerRoutes from "./modules/lawyers/lawyer.routes.js";
import chatbotModule from "./modules/chatbot/index.js";
import userRoutes from "./modules/users/user.routes.js";
import sessionRoutes from "./modules/sessions/session.routes.js";
import ocrModule from "./modules/ocr/index.js";
import templateRoutes from "./modules/template-generator/template.routes.js";

const app = express();

// ===== TRUST PROXY CONFIGURATION =====
// Trust X-Forwarded-For header from proxies/load balancers
// Required for accurate rate limiting and client IP detection
// Set to 1 to trust the immediate upstream proxy
// Set to higher numbers if behind multiple proxies (e.g., trust 2 for cloudflare → nginx → app)
app.set('trust proxy', process.env.TRUST_PROXY_HOPS || 1);

// ===== SECURITY MIDDLEWARE =====
// Helmet.js: Set security HTTP headers (relaxed for development)
app.use(helmet({
  contentSecurityPolicy: false, // Disable CSP for development
  hsts: false, // Disable HSTS for development
  frameguard: false,
  noSniff: true,
  xssFilter: true
}));

// Rate limiting disabled for development
// app.use(generalLimiter);

// ===== BODY PARSING & COOKIES =====
app.use(express.json({ limit: "5mb" }));
app.use(express.urlencoded({ limit: "5mb" }));
app.use(cookieParser());

// ===== CORS: Relaxed for development =====
const corsOptions = {
  origin: true, // Allow all origins for development
  credentials: true,
  methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"],
  maxAge: 3600 // Preflight cache in seconds
};

app.use(cors(corsOptions));

app.use("/api/chatbot", chatbotModule);
app.use("/api/users", userRoutes);
app.use("/api/sessions", sessionRoutes);
app.use("/api/templates", templateRoutes);
app.use("/api/ocr", ocrModule); // Uses multer for file uploads

app.get("/health", (req, res) => res.json({ ok: true }));

app.use("/api/lawyers", lawyerRoutes); // Uses express-fileupload (configured in routes)

export default app;