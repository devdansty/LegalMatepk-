import json
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch
from tqdm import tqdm

# --------------------------
# CONFIGURATION
# --------------------------
BASE_MODEL = "Qwen/Qwen2-7B-Instruct"          # base model name
FINETUNED_MODEL = "./qwen2-legalmate-lora"     # path to your fine-tuned model
DATASET_PATH = "legal_eval_dataset.json"       # dataset file

# --------------------------
# LOAD MODELS
# --------------------------
print("🔹 Loading tokenizer...")
tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL)

print("🔹 Loading base model...")
base_model = AutoModelForCausalLM.from_pretrained(
    BASE_MODEL,
    torch_dtype=torch.float16,
    device_map="auto"
)

print("🔹 Loading fine-tuned LegalMate model...")
finetuned_model = AutoModelForCausalLM.from_pretrained(
    FINETUNED_MODEL,
    torch_dtype=torch.float16,
    device_map="auto"
)

# --------------------------
# GENERATE FUNCTION
# --------------------------
def generate_response(model, query):
    inputs = tokenizer(query, return_tensors="pt").to(model.device)
    with torch.no_grad():
        outputs = model.generate(
            **inputs,
            max_new_tokens=300,
            temperature=0.7,
            top_p=0.9,
            pad_token_id=tokenizer.eos_token_id
        )
    return tokenizer.decode(outputs[0], skip_special_tokens=True)

# --------------------------
# LOAD EVALUATION DATASET
# --------------------------
with open(DATASET_PATH, "r", encoding="utf-8") as f:
    data = json.load(f)

results = []

print("\n⚖️ Evaluating models...\n")

for item in tqdm(data):
    query = item["query"]

    base_answer = generate_response(base_model, query)
    finetuned_answer = generate_response(finetuned_model, query)
    ideal = item["ideal_answer"]

    results.append({
        "query": query,
        "base_model_answer": base_answer,
        "finetuned_answer": finetuned_answer,
        "ideal_answer": ideal
    })

# --------------------------
# SAVE RESULTS TO FILE
# --------------------------
with open("evaluation_results.json", "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)

print("\n✅ Evaluation complete! Results saved in 'evaluation_results.json'")