import express from "express";
import chatbotModule from "./src/modules/chatbot/index.js";
import dotenv from "dotenv";

dotenv.config();

const app = express();
app.use(express.json());

// Mount modules
app.use("/api/chatbot", chatbotModule);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`🧠 Python API URL: ${process.env.PYTHON_API_URL}`);
});