import express from "express";
import { handleChat } from "./chatbot.controller.js";

const router = express.Router();

router.post("/", handleChat);

export default router;