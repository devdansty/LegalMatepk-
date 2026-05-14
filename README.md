# ⚖️ LegalMate.pk — AI-Powered Legal Assistant for Pakistan

[![Flutter](https://img.shields.io/badge/Mobile-Flutter_3.7-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Backend-Node.js_18+-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![Python](https://img.shields.io/badge/AI_Service-Python_3.10+-3776AB?logo=python&logoColor=white)](https://python.org)
[![MongoDB](https://img.shields.io/badge/Database-MongoDB-47A248?logo=mongodb&logoColor=white)](https://mongodb.com)
[![License: ISC](https://img.shields.io/badge/License-ISC-blue.svg)](https://opensource.org/licenses/ISC)

> **LegalMate** is a full-stack, AI-powered mobile platform that democratizes access to legal assistance in Pakistan. It combines a fine-tuned **Qwen2.5 LLM** with **RAG** (Retrieval-Augmented Generation), **OCR-based document summarization**, a **legal document template generator**, and a **lawyer marketplace** — all accessible through a beautiful Flutter mobile app.

---

## 📑 Table of Contents

- [Key Features](#-key-features)
- [System Architecture](#-system-architecture)
- [Technology Stack](#-technology-stack)
- [Project Structure](#-project-structure)
- [Backend Modules Deep Dive](#-backend-modules-deep-dive)
- [ML Service Deep Dive](#-ml-service-deep-dive)
- [Mobile App Screens](#-mobile-app-screens)
- [API Reference](#-api-reference)
- [Getting Started](#-getting-started)
- [Docker Deployment](#-docker-deployment)
- [Environment Variables](#-environment-variables)
- [DevOps & CI/CD](#-devops--cicd)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🌟 Key Features

| Feature | Description |
|---|---|
| **🤖 AI Legal Chatbot** | Real-time legal consultation powered by a fine-tuned **Qwen2.5-1.5B-Instruct** model with **LoRA** adapters, enhanced with **RAG** for high-accuracy Pakistani law answers. Supports **English**, **Urdu**, and **Roman Urdu** with streaming (SSE) responses. |
| **📄 Document Summarizer (OCR)** | Upload legal documents (PDF, JPG, PNG) and get AI-powered summaries. Uses a dual-engine OCR pipeline — **PaddleOCR** for standard text and **Google Vision AI** for complex Urdu script — followed by **Qwen2** model summarization. Includes broken-Urdu auto-repair. |
| **📑 Legal Template Generator** | Browse, fill, and download professional `.docx` legal documents (affidavits, sale deeds, rent agreements, FIRs, etc.) from a seeded template library across 8 categories (Property, Family, Criminal, Corporate, NADRA, Court Applications, etc.). |
| **👨‍⚖️ Lawyer Marketplace** | Citizens browse verified lawyers by specialization (Family, Criminal, Corporate, Property, Cybercrime, Immigration), send connection requests, and receive contact details upon acceptance. Lawyers register with CNIC and Bar Council verification. |
| **🔐 Authentication & Security** | Email/password signup with OTP email verification, Google OAuth, guest access (5-call limit), JWT + refresh token sessions, Argon2id password hashing, field-level encryption (phone, CNIC), Helmet security headers, and rate limiting. |
| **👤 User Management** | Role-based access (Citizen, Lawyer, Admin, Guest), profile management, password change via OTP, account deletion with full data cascade, and session management. |

---

## 🏗️ System Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                        MOBILE CLIENT (Flutter / Dart)                │
│  GetX State Management · Google Fonts · Lottie Animations            │
│  Firebase Auth · Google Sign-In · Speech-to-Text · TTS               │
└───────────────────────────────┬──────────────────────────────────────┘
                                │  REST API (HTTPS)
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│                   BACKEND ORCHESTRATOR (Node.js / Express 5)         │
│                                                                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐ ┌─────────┐  │
│  │ Users    │ │ Chatbot  │ │   OCR    │ │ Templates  │ │ Lawyers │  │
│  │ Module   │ │ Module   │ │ Module   │ │ Module     │ │ Module  │  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └─────┬──────┘ └────┬────┘  │
│       │             │            │              │             │       │
│  ┌────┴─────────────┴────────────┴──────────────┴─────────────┴───┐  │
│  │          Shared: Auth Middleware · Guest Tracking               │  │
│  │          Rate Limiting · Email Service · Encryption Service     │  │
│  └────────────────────────────────────────────────────────────────┘  │
└───────────────────┬───────────────────────┬──────────────────────────┘
                    │                       │
         ┌──────────▼──────────┐   ┌────────▼────────┐
         │  MongoDB (Mongoose) │   │  ML Service      │
         │  Users, Lawyers,    │   │  (Python/FastAPI) │
         │  Chat Sessions,     │   │                   │
         │  OCR Results,       │   │  ┌─────────────┐  │
         │  Templates,         │   │  │ Chatbot API │  │
         │  Connections        │   │  │ Qwen2.5+LoRA│  │
         └─────────────────────┘   │  └─────────────┘  │
                                   │  ┌─────────────┐  │
                                   │  │  OCR Engine  │  │
                                   │  │ PaddleOCR +  │  │
                                   │  │ Vision AI    │  │
                                   │  └─────────────┘  │
                                   └───────────────────┘
```

---

## 🛠️ Technology Stack

### Frontend (Mobile)
| Technology | Purpose |
|---|---|
| Flutter (Dart) `^3.7` | Cross-platform mobile framework |
| GetX | Navigation & state management |
| Google Fonts, Lottie, Flutter Animate | UI/UX & animations |
| Firebase Auth + Google Sign-In | Social authentication |
| Speech-to-Text / Flutter TTS | Voice input & output |
| File Picker / Image Picker | Document & image uploads |
| Flutter Secure Storage | Secure token persistence |

### Backend (Node.js)
| Technology | Purpose |
|---|---|
| Express.js v5 (ES Modules) | HTTP server framework |
| MongoDB + Mongoose v8 | Database & ODM |
| JWT + Argon2id | Authentication & password hashing |
| Helmet, CORS, express-rate-limit | Security middleware |
| Multer / express-fileupload | File upload handling |
| Nodemailer | OTP email delivery |
| Docx.js + Python (docx-template) | Legal document generation |
| google-auth-library | Google OAuth verification |

### AI / Machine Learning (Python)
| Technology | Purpose |
|---|---|
| FastAPI + Uvicorn | High-performance API server |
| Qwen2.5-1.5B-Instruct + LoRA (PEFT) | Fine-tuned legal chatbot LLM |
| RAG (Retrieval-Augmented Generation) | Context-enriched legal answers |
| PaddleOCR | Primary OCR engine (English + mixed) |
| Google Cloud Vision AI | Secondary OCR engine (Urdu/complex) |
| PyTorch, Transformers, bitsandbytes | Model inference (8-bit quantization) |

---

## 📁 Project Structure

```
LegalMatepk-/
├── mobile/                          # Flutter Mobile Application
│   └── lib/
│       ├── screens/                 # 18 screens (chat, OCR, templates, lawyers, auth...)
│       ├── services/                # API services (template, STT)
│       ├── models/                  # Data models
│       └── config/                  # App configuration
│
├── backend/                         # Node.js/Express Backend
│   └── src/
│       ├── app.js                   # Express app + route mounting
│       ├── server.js                # Entry point (MongoDB connection + listen)
│       └── modules/
│           ├── users/               # Auth, profile, password management
│           ├── chatbot/             # AI chat with streaming (SSE)
│           ├── ocr/                 # Document upload + summarization
│           ├── template-generator/  # Legal template CRUD + .docx generation
│           ├── lawyers/             # Lawyer registration + connection system
│           └── sessions/            # JWT refresh token rotation
│       └── shared/
│           ├── middleware/          # auth, guest tracking, rate limiting
│           └── services/            # email, encryption
│
├── ml-service/                      # Python AI Microservices
│   ├── chatbot/
│   │   ├── finalChatbot/            # Production chatbot API (Qwen2.5 + LoRA + RAG)
│   │   ├── RAG/                     # Retrieval-Augmented Generation pipeline
│   │   ├── ChatBot-models/          # Fine-tuned model checkpoints
│   │   └── codeForTraining/         # Training scripts & notebooks
│   ├── ocr/                         # OCR FastAPI service
│   │   ├── services/                # PaddleOCR, Vision AI, language detector
│   │   └── routes/                  # OCR extraction endpoints
│   └── extras/                      # Experimental utilities
│
├── docs/                            # Datasets & legal templates (.docx)
│   ├── legal-templates/             # Source .docx template files
│   ├── Pak-Legal-Dataset/           # Preprocessed Pakistani law corpus
│   ├── Supreme_court_Of_Pakistan_judgments/
│   └── dataForTraining-chatBot/     # Training data
│
├── Documentation/                   # Academic project reports & presentations
├── docker/                          # Docker configuration (containerization)
├── .github/workflows/               # CI/CD pipelines (GitHub Actions)
├── devopsguide.md                   # Comprehensive DevOps deployment guide
└── .gitignore
```

---

## 🧩 Backend Modules Deep Dive

### 1. Users Module (`/api/users`)
Complete authentication system with multi-provider support.

| Endpoint | Method | Auth | Description |
|---|---|---|---|
| `/signup` | POST | ✗ | Email/password registration with OTP |
| `/signin` | POST | ✗ | Login with session creation |
| `/google-auth` | POST | ✗ | Google OAuth sign-in/sign-up |
| `/dev-guest-login` | POST | ✗ | Guest access (5-call limit) |
| `/email-otp/send` | POST | ✗ | Send email verification OTP |
| `/email-otp/verify` | POST | ✗ | Verify email OTP |
| `/me` | GET | ✓ | Get user profile |
| `/me` | PUT | ✓ | Update profile |
| `/me` | DELETE | ✓ | Delete account (cascades all data) |
| `/change-password` | POST | ✓ | Change password (old password required) |
| `/change-password-otp` | POST | ✓ | Change password via OTP |
| `/password-reset/request` | POST | ✗ | Request password reset |
| `/password-reset/confirm` | POST | ✗ | Confirm password reset |

### 2. Chatbot Module (`/api/chatbot`)
AI-powered legal consultation with real-time streaming.

| Endpoint | Method | Auth | Description |
|---|---|---|---|
| `/` | POST | Optional | Send message (supports SSE streaming + image attachment with OCR) |
| `/history` | GET | ✓ | Get paginated chat history |
| `/history` | DELETE | ✓ | Clear all chat history |
| `/sessions` | POST | ✓ | Create new chat session |
| `/sessions` | GET | ✓ | List all chat sessions |
| `/sessions/:chatId/messages` | GET | ✓ | Get messages for a session |
| `/sessions/:chatId` | DELETE | ✓ | Delete a chat session |

### 3. OCR / Document Summarizer Module (`/api/ocr`)
Upload documents → OCR text extraction → AI summarization.

| Endpoint | Method | Auth | Description |
|---|---|---|---|
| `/` | POST | ✓ | Upload document for OCR + AI summary |
| `/` | GET | ✓ | Get paginated OCR history |
| `/:ocrResultId` | GET | ✓ | Get specific OCR result |
| `/:ocrResultId` | DELETE | ✓ | Soft-delete an OCR result |

**Pipeline:** Upload → PaddleOCR/Vision AI → Language Detection → Broken-Urdu Repair → Qwen2 Summarization → MongoDB persistence. Includes duplicate detection to skip redundant model calls.

### 4. Template Generator Module (`/api/templates`)
Legal document template library with dynamic `.docx` generation.

| Endpoint | Method | Auth | Description |
|---|---|---|---|
| `/` | GET | ✗ | List templates (filter by category/search) |
| `/:id` | GET | ✗ | Get template by ID |
| `/slug/:slug` | GET | ✗ | Get template by slug |
| `/categories` | GET | ✗ | List all template categories |
| `/generate` | POST | ✓ | Generate filled `.docx` from template |
| `/:id/download-original` | GET | ✗ | Download original template file |
| `/` | POST | ✗ | Create new template |
| `/bulk` | POST | ✗ | Bulk insert templates |
| `/:id` | PUT | ✗ | Update template |
| `/:id` | DELETE | ✗ | Soft/hard delete template |

**Categories:** Property, Family, Criminal, Corporate, General, NADRA, Court Application, Other.

### 5. Lawyers Module (`/api/lawyers`)
Lawyer verification and citizen-lawyer connection system.

| Endpoint | Method | Auth | Description |
|---|---|---|---|
| `/signup` | POST | ✗ | Lawyer registration (CNIC + License uploads) |
| `/` | GET | ✗ | List all verified lawyers |
| `/profile/:lawyerId` | GET | ✗ | View lawyer public profile |
| `/request` | POST | ✓ | Send connection request to lawyer |
| `/requests/incoming` | GET | ✓ | Lawyer views incoming requests |
| `/requests/respond` | POST | ✓ | Lawyer accepts/rejects request |
| `/my-connections` | GET | ✓ | User views accepted connections |
| `/me/profile` | GET | ✓ | Lawyer views own profile |
| `/me/profile` | PUT | ✓ | Lawyer updates own profile |

### 6. Sessions Module (`/api/sessions`)
JWT refresh token rotation and session lifecycle.

| Endpoint | Method | Auth | Description |
|---|---|---|---|
| `/refresh` | POST | ✗ | Refresh access token (HTTP-only cookie) |
| `/logout` | POST | ✓ | Revoke current session |
| `/` | GET | ✓ | List active sessions |

---

## 🧠 ML Service Deep Dive

### Chatbot Service (Qwen2.5 + LoRA + RAG)
- **Base Model:** `Qwen/Qwen2.5-1.5B-Instruct`
- **Fine-tuning:** LoRA adapters trained on Pakistani legal corpus (Roman Urdu + English + Urdu)
- **RAG Pipeline:** Vector database (ChromaDB) with Pakistani law embeddings for retrieval-augmented generation
- **Inference:** 8-bit quantized (`load_in_8bit=True`) for efficient GPU/CPU usage
- **Streaming:** FastAPI endpoint with real-time token generation
- **Trilingual:** Automatic language detection and response matching (English ↔ Urdu ↔ Roman Urdu)

### OCR Service (PaddleOCR + Vision AI)
- **Primary Engine:** PaddleOCR v2.7 — for English and mixed-script documents
- **Secondary Engine:** Google Cloud Vision AI — for complex Urdu/Nastaliq script
- **Language Detection:** Automatic script detection (English, Urdu, Mixed) with smart routing
- **Supported Formats:** PDF, JPG, JPEG, PNG (up to 25 MB)

---

## 📱 Mobile App Screens

| Screen | Description |
|---|---|
| `splash_screen` | Animated app launch screen |
| `role_selection_screen` | Choose Citizen or Lawyer role |
| `citizen_signup_screen` | Citizen registration form |
| `lawyer_signup_screen` | Lawyer registration with document uploads |
| `signin_screen` | Email/password + Google OAuth login |
| `home_screen` | Main dashboard with feature navigation |
| `chatbot_screen` | AI legal chatbot with streaming, voice input, and image attachment |
| `ocr_screen` | Document upload + AI summarization viewer |
| `legaltemplate_screen` | Browse templates by category |
| `template_detail_screen` | View template details & fields |
| `template_form_screen` | Fill template fields dynamically |
| `template_preview_screen` | Preview & download generated `.docx` |
| `document_preview_screen` | Document content viewer |
| `lawyer_connect_screen` | Browse & filter lawyers |
| `lawyer_profile_screen` | Lawyer detail view + send request |
| `lawyer_dashboard` | Lawyer incoming requests management |
| `lawyers_msgs` | Lawyer-citizen messaging interface |
| `user_profile_screen` | User profile & settings management |

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Flutter SDK | `^3.7.0` | Mobile app development |
| Node.js | `v18+` | Backend server |
| Python | `3.10+` | ML/AI services |
| MongoDB | `6.0+` | Database |
| Docker _(optional)_ | Latest | Containerized deployment |

### 1. Backend Setup

```bash
cd backend
npm install

# Create environment file (see Environment Variables section)
cp .env.example .env

# Start in development mode
npm run dev

# Or start in production mode
npm start
```

### 2. ML Chatbot Service Setup

```bash
cd ml-service/chatbot/finalChatbot

# Install dependencies
pip install -r requirements.txt

# Run the API server
python legalmate_api_local.py
# Server starts at http://localhost:8000
```

### 3. OCR Service Setup

```bash
cd ml-service/ocr

# Install dependencies
pip install -r requirements.txt

# Run the OCR service
uvicorn main:app --host 0.0.0.0 --port 8001
```

### 4. Mobile App Setup

```bash
cd mobile
flutter pub get

# Run on connected device/emulator
flutter run
```

---

## 🐳 Docker Deployment

Orchestrate all services with Docker Compose:

```bash
# Build and start all containers
docker-compose up --build -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

This spins up:
- **Backend** container (Node.js on port `3000`)
- **ML Service** container (Python/FastAPI on port `8000`)
- **MongoDB** container (port `27017`, internal only)

> See [devopsguide.md](devopsguide.md) for detailed Docker, CI/CD, AWS, and monitoring documentation.

---

## 🔐 Environment Variables

Create a `.env` file in the `backend/` directory:

```env
# Server
PORT=3000
NODE_ENV=development

# MongoDB
MONGODB_URI=mongodb://localhost:27017/legalmate

# JWT
JWT_SECRET=your-strong-secret-key
JWT_EXP=15m

# ML Services
PYTHON_API_URL=http://localhost:8000
PYTHON_OCR_SERVICE_URL=http://localhost:8001
QWEN2_MODEL_URL=http://localhost:8000

# Google OAuth
GOOGLE_CLIENT_ID=your-google-client-id

# Email (Nodemailer)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password

# Encryption
ENCRYPTION_KEY=your-32-byte-hex-key

# Google Vision AI (for OCR)
GOOGLE_VISION_API_KEY=your-api-key
```

---

## 🔄 DevOps & CI/CD

The project includes a complete DevOps pipeline:

- **GitHub Actions** — Automated Docker image builds on push to `main`/`develop`
- **Docker Hub** — Image registry for backend and ML service containers
- **AWS EC2** — Production deployment (recommended: `t3.medium` or `t3.large`)
- **Health Checks** — Built-in container health monitoring
- **Structured Logging** — Request logging middleware with timing metrics

📖 Full guide: [devopsguide.md](devopsguide.md)

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📜 License

Distributed under the **ISC License**. See `LICENSE` for more information.

---

## 👥 Team

**LegalMate** — Final Year Project  
🔗 [github.com/devdansty/LegalMatepk-](https://github.com/devdansty/LegalMatepk-)

---

*Built with ❤️ to make legal assistance accessible to every citizen of Pakistan.*