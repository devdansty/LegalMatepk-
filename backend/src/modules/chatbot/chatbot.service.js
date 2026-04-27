import axios from "axios";

export const pythonClient = axios.create({
  // baseURL: process.env.PYTHON_API_URL,
  baseURL: process.env.PYTHON_API_URL,
  timeout: 60000, // AI/RAG responses can be slow
});

/**
 * Internal method - sends prompt to Python chatbot and returns raw stream.
 */
const _sendToPythonStream = async (message) => {
  try {
    const response = await pythonClient.post("/generate", {
      prompt: message
    }, {
      responseType: 'stream'
    });

    return response.data;
  } catch (error) {
    console.error("Error calling Python API:", error?.message);
    throw error;
  }
};

export const chatBotApiStream = async (message) => {
  try {
    console.log("\n📥 Chatbot Streaming Request Received:");
    console.log(`   Original Message: "${message.slice(0, 60)}..."`);
    console.log(`   Message Length: ${message.length} chars`);
    console.log("   Mode: Direct streaming");

    console.log(`\n🚀 Opening Python Chatbot stream:`);
    console.log(`   URL: ${process.env.PYTHON_API_URL}`);

    return await _sendToPythonStream(message);
  } catch (error) {
    console.error("\n❌ RAG Stream Error:", error?.message);
    console.error("📋 Error Stack:", error?.stack);
    throw new Error("LegalMate AI is currently offline.");
  }
};

/**
 * Main chatbot API (direct pass-through mode)
 * Sends user text to Python chatbot as-is and returns response as-is.
 */
export const chatBotApi = async (message) => {
  try {
    console.log("\n📥 Chatbot Request Received:");
    console.log(`   Original Message: "${message.slice(0, 60)}..."`);
    console.log(`   Message Length: ${message.length} chars`);
    console.log("   Mode: Direct (translation disabled)");

    // Send to Python chatbot
    console.log(`\n🚀 Sending to Python Chatbot Service:`);
    console.log(`   URL: ${process.env.PYTHON_API_URL}`);
    console.log(`   Message: "${message.slice(0, 60)}..."`);
    
    const stream = await _sendToPythonStream(message);

    const response = await new Promise((resolve, reject) => {
      let fullResponse = "";

      stream.on("data", (chunk) => {
        fullResponse += chunk.toString();
      });

      stream.on("end", () => {
        if (fullResponse) {
          resolve(fullResponse);
        } else {
          resolve("I couldn't generate a legal response at this time.");
        }
      });

      stream.on("error", (error) => {
        reject(error);
      });
    });

    console.log(`\n✅ Python Service Response Received:`);
    console.log(`   Response: "${response.slice(0, 60)}..."`);

    console.log(`\n✅ Request Complete - Sending to Client\n`);
    return response;

  }  catch (error) {
    console.error("\n❌ RAG Service Error:", error?.message);
    console.error("📋 Error Stack:", error?.stack);
    throw new Error("LegalMate AI is currently offline.");
  }
};