import express from "express";
import chatbotModule from "./src/modules/chatbot/index.js";
import dotenv from "dotenv";

dotenv.config();

const app = express();
app.use(express.json());

// Mount modules
app.use("/api/chatbot", chatbotModule);

export default app;