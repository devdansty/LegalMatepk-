import { chatBotApi } from "./chatbot.service.js";

export const handleChat = async (req, res) => {
  try {
    const { message } = req.body;

    const reply = await chatBotApi(message);

    res.json({
      success: true,
      reply
    });

  } catch (error) {
    console.error("Chatbot Error:", error.message);

    res.status(500).json({
      success: false,
      error: "Chatbot unavailable"
    });
  }
};