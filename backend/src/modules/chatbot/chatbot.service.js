import axios from "axios";
import { translateIfUrdu, translateToUrdu } from "../../shared/language/translation.service.js";
import { detectLanguage } from "../../shared/language/language.utils.js";

export const pythonClient = axios.create({
  baseURL: process.env.PYTHON_API_URL || "https://garnishable-shawna-automotive.ngrok-free.dev",
  timeout: 60000, // AI/RAG responses can be slow
});

/**
 * Internal method - sends prompt to Python chatbot
 */
const _sendToPython = async (message) => {
  const response = await pythonClient.post("/generate", {
    prompt: message
  });

  if (response.data && response.data.response) {
    return response.data.response;
  }

  return "I couldn't generate a legal response at this time.";
};

/**
 * Main chatbot API with integrated translation
 * Handles Urdu→English translation before sending to Python
 * Translates responses back to Urdu if original input was Urdu
 * Implementation is transparent - translation happens automatically
 */
export const chatBotApi = async (message) => {
  try {
    console.log("\n📥 Chatbot Request Received:");
    console.log(`   Original Message: "${message.slice(0, 60)}..."`);
    console.log(`   Message Length: ${message.length} chars`);

    // Detect original language
    const originalLanguage = detectLanguage(message);
    console.log(`   ✅ Detected Language: ${originalLanguage === "ur" ? "URDU 🇵🇰" : "ENGLISH 🇬🇧"}`);

    let processedMessage = message;
    let needsUrduResponse = originalLanguage === "ur";

    // Translate Urdu to English if needed
    if (needsUrduResponse) {
      console.log(`\n🔄 Translating Urdu → English:`);
      processedMessage = await translateIfUrdu(message);
      console.log(`   ✅ Translation Complete!`);
      console.log(`   Translated: "${processedMessage.slice(0, 60)}..."`);
      console.log(`   Translation Length: ${processedMessage.length} chars`);
    } else {
      console.log(`\n⏭️  No translation needed (English detected)`);
    }

    // Send to Python chatbot
    console.log(`\n🚀 Sending to Python Chatbot Service:`);
    console.log(`   URL: ${process.env.PYTHON_API_URL}`);
    console.log(`   Message: "${processedMessage.slice(0, 60)}..."`);
    
    let response = await _sendToPython(processedMessage);

    console.log(`\n✅ Python Service Response Received:`);
    console.log(`   Response: "${response.slice(0, 60)}..."`);

    // Translate response back to Urdu if original was Urdu
    if (needsUrduResponse) {
      console.log(`\n🔄 Translating Response back to Urdu:`);
      response = await translateToUrdu(response);
      console.log(`   ✅ Response Translated to Urdu!`);
      console.log(`   Final Response: "${response.slice(0, 60)}..."`);
    }

    console.log(`\n✅ Request Complete - Sending to Client\n`);
    return response;

  } catch (error) {
    console.error("\n❌ RAG Service Error:", error?.message);
    console.error("📋 Error Stack:", error?.stack);
    throw new Error("LegalMate AI is currently offline.");
  }
};