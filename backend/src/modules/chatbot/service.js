import axios from "axios";

export const pythonClient = axios.create({
  baseURL: process.env.PYTHON_API_URL || "https://garnishable-shawna-automotive.ngrok-free.dev", // Ensure this is set in .env
  timeout: 60000, // Legal RAG might take time, set a reasonable timeout
});

export const chatBotApi = async (message) => {
  try {
    // We send the raw user message; Python handles the Pinecone lookup
    const response = await pythonClient.post("/generate", { prompt: message });

    if (response.data && response.data.response) {
      return response.data.response;
    }
    return "I couldn't generate a legal response at this time.";
  } catch (error) {
    console.error("❌ RAG Service Error:", error?.message);
    throw new Error("LegalMate AI is currently offline.");
  }
};