# 🏛️ LegalMate Backend — Project Structure Guide

This document explains the **folder structure**, **responsibilities of each layer**, and **how the chatbot module is organized** in the LegalMate backend.
The structure is intentionally kept **simple yet scalable**, so more modules (like authentication, user profiles, or legal document management) can be added later without refactoring the codebase.

---

## 📂 Folder Structure Overview

```
backend/
│
├── src/
│   ├── app.js                 # Express app setup and module registration
│   ├── server.js              # Main entry point that starts the backend
│   │
│   ├── config/                # Configuration files (env, database, constants)
│   │   └── env.js
│   │
│   ├── modules/               # Each independent feature lives here
│   │   └── chatbot/           # Chatbot module (LegalMate AI)
│   │        ├── chatbot.routes.js
│   │        ├── chatbot.controller.js
│   │        ├── chatbot.service.js
│   │        └── index.js
│   │
│   ├── integrations/          # External API clients (Python ML, 3rd-party services)
│   │   └── pythonClient.js
│   │
│   ├── middleware/            # Custom Express middleware (optional)
│   │   └── errorHandler.js
│   │
│   └── utils/                 # Reusable helper functions and utilities
│       └── logger.js
│
├── .env                       # Environment variables (PORT, Python API URL, etc.)
├── package.json
└── README.md
```

---

## 🧩 Folder-by-Folder Explanation

### **`/src/app.js`**

This is the main Express application file.
It initializes middleware (like `express.json()`), mounts all modules, and exports the configured Express app.

When new modules (like `/auth` or `/documents`) are added, their routers are imported and registered here.

---

### **`/src/server.js`**

The entry point of the backend.
It loads environment variables, imports the Express app from `app.js`, and starts the HTTP server on the specified port.

Example:

```js
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
```

---

### **`/src/config/`**

Stores configuration-related files, constants, or environment variable setup.
For example:

* `env.js` can centralize reading and validating environment variables.
* Later, you can add `db.js` if you connect to MongoDB or PostgreSQL.

---

### **`/src/modules/`**

This is the **core folder** of the backend.
Each module represents a **distinct feature** or domain of the LegalMate application (e.g. chatbot, users, authentication, case management, etc.).

Every module is self-contained with its own:

* **routes** — defines endpoints
* **controllers** — handles HTTP requests/responses
* **services** — performs logic, integrates APIs or databases
* **index.js** — exports the module router

#### Example (Chatbot module)

```
chatbot/
 ├── chatbot.routes.js
 ├── chatbot.controller.js
 ├── chatbot.service.js
 └── index.js
```

---

### **`/src/integrations/`**

Contains reusable API clients that connect to **external services** — such as the Python ML/Chatbot API.

For instance, `pythonClient.js` is a preconfigured `axios` instance that communicates with your Python-based LegalMate AI model.
By keeping integrations here, any external system (e.g., Gemini API, email API, or another microservice) can be added cleanly.

---

### **`/src/middleware/`**

Holds Express middleware functions used globally or by specific routes.
Examples:

* Authentication (`auth.middleware.js`)
* Error handling (`errorHandler.js`)
* Logging or request validation middleware

---

### **`/src/utils/`**

Contains helper functions or utilities used across modules.
Examples:

* Logging utility (`logger.js`)
* Formatters, validators, and reusable small logic blocks

---

## 🧠 Understanding the Controller Layer

**Purpose:**
Controllers are the **middle managers** of the backend — they sit between the **routes (entry points)** and the **services (business logic)**.

**Responsibilities:**

* Receive incoming HTTP requests from the client (via routes)
* Extract request data (e.g. `req.body`, `req.params`)
* Call the appropriate service to perform business logic
* Format and return the response to the client
* Handle errors gracefully

Example:

```js
// chatbot.controller.js
import { sendToPython } from "./chatbot.service.js";

export const handleChat = async (req, res) => {
  try {
    const { message } = req.body;
    const reply = await sendToPython(message);
    res.json({ success: true, reply });
  } catch (err) {
    console.error("Chatbot Error:", err.message);
    res.status(500).json({ success: false, error: "Chatbot unavailable" });
  }
};
```

👉 Controllers **should not** contain heavy logic or database queries —
they only coordinate between the client request and the internal service.

---

## ⚙️ Request Flow (Example)

Here’s how a request from the Flutter frontend travels through the backend:

```
1️⃣ Flutter sends POST /api/chatbot
    ↓
2️⃣ chatbot.routes.js — defines endpoint and calls controller
    ↓
3️⃣ chatbot.controller.js — processes request & calls service
    ↓
4️⃣ chatbot.service.js — sends message to Python ML API
    ↓
5️⃣ pythonClient.js — communicates with Python model
    ↓
6️⃣ Python API responds with chatbot reply
    ↓
7️⃣ Node.js backend sends the final response back to Flutter
```

---

## 🪴 How to Scale Later

When adding new modules, simply create a new folder inside `/src/modules/`,
and follow the same 3-layer pattern:

```
modules/
 ├── chatbot/
 ├── auth/
 ├── user/
 ├── document/
 └── ...
```

Each module has:

* its own `routes.js`
* its own `controller.js`
* its own `service.js`

No files conflict, and the structure stays organized even as the project grows.

---

## ✅ Summary

| Folder / File       | Purpose                                             |
| ------------------- | --------------------------------------------------- |
| **`src/app.js`**    | Initialize Express app and mount modules            |
| **`src/server.js`** | Start server and manage environment                 |
| **`config/`**       | Configuration files (env, db, constants)            |
| **`modules/`**      | Feature-based folders (chatbot, auth, etc.)         |
| **`controllers/`**  | Handle requests & responses                         |
| **`services/`**     | Contain business logic or API calls                 |
| **`integrations/`** | Reusable clients for external APIs (like Python ML) |
| **`middleware/`**   | Authentication, validation, or error handling       |
| **`utils/`**        | Helpers and shared utilities                        |