import app from "./app.js";

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`🧠 Python API URL: ${process.env.PYTHON_API_URL}`);
});