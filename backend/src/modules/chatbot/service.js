import { pythonClient } from "../../integrations/python.client.js";

export const sendToPython = async (message) => {
    console.log("🔗 Using Python API URL:", process.env.PYTHON_API_URL);
    console.log("📡 Full request URL:", pythonClient.defaults.baseURL + "/generate");
  try {
    const response = await pythonClient.post("/generate", { prompt: message });
    return response.data.response;
  } catch (error) {
    console.error("❌ Error calling Python API:", error.message);
    throw new Error("Python service unavailable");
  }
};