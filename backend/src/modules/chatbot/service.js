import axios from "axios";

// Single local axios client for contacting the Python service.
export const pythonClient = axios.create({
  baseURL: process.env.PYTHON_API_URL || "https://garnishable-shawna-automotive.ngrok-free.dev",
  timeout: 1000000000,
});

export const chatBotApi = async (message) => {
    // console.log("🔗 Using Python API URL:", process.env.PYTHON_API_URL);
    // console.log("📡 Full request URL:", pythonClient.defaults.baseURL + "/generate");
  try {
    const response = await pythonClient.post("/generate", { prompt: message });
    console.log("✅ Received response from Python API:", response && response.data ? response.data : response);
    // Be defensive: check structure before returning
    return response && response.data && Object.prototype.hasOwnProperty.call(response.data, 'response')
      ? response.data.response
      : null;
  } catch (error) {
    console.error("❌ Error calling Python API:", error?.message || error);
    throw new Error("Python service unavailable");
  }
};
