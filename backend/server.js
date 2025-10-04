const express = require("express");
const cors = require("cors");
require("dotenv").config();

const app = express();
app.use(cors());
app.use(express.json());

// test route
app.get("/", (req, res) => {
  res.send("Backend working!");
});

// chat endpoint (dummy for now)
app.post("/api/chat", (req, res) => {
  const { text } = req.body;
  res.json({ answer: "This is a dummy answer for: " + text });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));