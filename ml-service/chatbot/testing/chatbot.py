from transformers import AutoTokenizer, AutoModelForCausalLM
import torch

# --------------------------
# 1️⃣  Set your model path
# --------------------------
MODEL_PATH = "Qwen/Qwen2-0.5B"   # change this if your model folder has a different name

# --------------------------
# 2️⃣  Load model and tokenizer (robust to CPU/GPU)
# --------------------------
print("🔹 Loading your LegalMate model...")

tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)

# Load model with sensible defaults for GPU/CPU
try:
    if torch.cuda.is_available():
        model = AutoModelForCausalLM.from_pretrained(
            MODEL_PATH,
            torch_dtype=torch.float16,
            device_map="auto",
            trust_remote_code=True
        )
    else:
        model = AutoModelForCausalLM.from_pretrained(
            MODEL_PATH,
            torch_dtype=torch.float32,
            low_cpu_mem_usage=True,
            trust_remote_code=True
        )
        model.to("cpu")
except Exception as e:
    # fallback: try without trust_remote_code (if model is local and standard)
    print("⚠️ Primary load failed, retrying without trust_remote_code:", e)
    if torch.cuda.is_available():
        model = AutoModelForCausalLM.from_pretrained(MODEL_PATH, torch_dtype=torch.float16, device_map="auto")
    else:
        model = AutoModelForCausalLM.from_pretrained(MODEL_PATH, torch_dtype=torch.float32, low_cpu_mem_usage=True)
        model.to("cpu")

# --------------------------
# 3️⃣  Start simple chat loop
# --------------------------
print("\n💬 LegalMate Chatbot is ready! (type 'exit' to quit)\n")

while True:
    query = input("👤 You: ").strip()
    if query.lower() in ["exit", "quit"]:
        print("👋 Goodbye!")
        break

    inputs = tokenizer(query, return_tensors="pt")
    inputs = {k: v.to(model.device) for k, v in inputs.items()}

    with torch.no_grad():
        outputs = model.generate(
            **inputs,
            max_new_tokens=300,
            temperature=0.7,
            top_p=0.9,
            pad_token_id=tokenizer.eos_token_id
        )

    response = tokenizer.decode(outputs[0], skip_special_tokens=True)

    # remove repeated user text from start if needed
    if response.startswith(query):
        response = response[len(query):].strip()

    print(f"🤖 LegalMate: {response}\n")