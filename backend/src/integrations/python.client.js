import axios from "axios";

const base = process.env.PYTHON_API_URL;
console.log("🔗 Using Python API URL:", base);

export const pythonClient = axios.create({
  baseURL: process.env.PYTHON_API_URL || "https://garnishable-shawna-automotive.ngrok-free.dev",
  timeout: 6000,
});
