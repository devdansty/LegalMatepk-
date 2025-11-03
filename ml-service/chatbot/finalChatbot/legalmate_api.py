# ============================================
# ⚖️ LegalMate AI Chatbot API Service
# ============================================
# This script hosts your fine-tuned Qwen2.5 + LoRA model as a REST API.
# Node.js or Flutter can send a prompt and receive a generated answer.

from fastapi import FastAPI, Request
from pydantic import BaseModel
from transformers import AutoTokenizer, AutoModelForCausalLM
from peft import PeftModel
import torch
import uvicorn

# -------- CONFIGURATION --------
BASE_MODEL = ""
LORA_PATH = ""   # path to your latest fine-tuned model

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# -------- INITIALIZATION --------
print("🚀 Loading tokenizer and model...")
tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL, trust_remote_code=True)
if tokenizer.pad_token is None:
    tokenizer.pad_token = tokenizer.eos_token

model = AutoModelForCausalLM.from_pretrained(
    BASE_MODEL,
    device_map="auto",
    load_in_8bit=True,
    torch_dtype=torch.bfloat16,
    trust_remote_code=True
)
model = PeftModel.from_pretrained(model, LORA_PATH)
model.eval()

print("✅ Model ready on", DEVICE)

# -------- FASTAPI APP --------
app = FastAPI(title="LegalMate AI API", version="1.0")

class Query(BaseModel):
    prompt: str
    max_new_tokens: int = 200
    temperature: float = 0.7
    top_p: float = 0.9

SYSTEM_PROMPT = """
You are LegalMate — an intelligent, bilingual legal chatbot assistant developed to help users understand and discuss legal matters.

🧾 Your role:
- Provide accurate, concise, and clear legal information (not legal advice).
- Explain legal concepts in easy and understandable language.
- Maintain a professional, respectful, and neutral tone.

🌍 Languages you understand and can respond in:
- English 🇬🇧
- Urdu 🇵🇰 (اردو)
- Roman Urdu (e.g., “Mujhe bail ka process samjhao.”)

💬 Behavior guidelines:
- If the user speaks in English → reply in English.
- If the user speaks in Urdu script → reply in Urdu.
- If the user speaks in Roman Urdu → reply in Roman Urdu.
- Always stay polite, professional, and helpful.
- Keep answers short (2–4 sentences) unless a detailed explanation is clearly required.
- Never give personal legal advice — provide general legal understanding or procedural info only.

🎓 Example:
User: "Mujhe divorce process batao."
LegalMate: "Pakistan ke law ke mutabiq, divorce ke liye talaq ka notice Union Council me file hota hai, aur ek iddat period hota hai."

Now, continue the conversation accordingly.
"""

@app.post("/generate")
async def generate_text(query: Query):
    """
    Generate a response for a given prompt.
    """
    try:
        # Combine system prompt with user input
        full_prompt = f"{SYSTEM_PROMPT}\n\nUser: {query.prompt}\nLegalMate:"
        
        inputs = tokenizer(full_prompt, return_tensors="pt").to(DEVICE)

        with torch.no_grad():
            output = model.generate(
                **inputs,
                max_new_tokens=query.max_new_tokens,
                temperature=query.temperature,
                top_p=query.top_p,
                do_sample=True,
                pad_token_id=tokenizer.eos_token_id
            )

        response = tokenizer.decode(output[0], skip_special_tokens=True)
        # Remove system prompt text if repeated
        response = response.replace(SYSTEM_PROMPT.strip(), "").strip()
        return {"response": response}

    except Exception as e:
        return {"error": str(e)}


@app.get("/")
async def root():
    return {"message": "LegalMate AI API is running 🧠"}


# -------- ENTRY POINT --------
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)