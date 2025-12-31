# ============================================
# 🪄 Roman Urdu Dataset → Instruction JSONL
# ============================================

import pandas as pd
import json

# --- STEP 1: Path setup ---
# Replace this with your downloaded CSV file path
input_csv = r"E:\CODE\FYP\application\ml-service\chatbot\ChatBot-models(qwen2.5-1.5B-instructor)\trainingData\RomanUrduDataSet.csv"
output_jsonl = r"E:\CODE\FYP\application\ml-service\chatbot\ChatBot-models(qwen2.5-1.5B-instructor)\trainingData\roman_urdu_qa.jsonl"

# --- STEP 2: Load dataset ---
df = pd.read_csv(input_csv, header=None, names=["review", "sentiment", "extra"])
print("✅ Dataset loaded:", df.shape)

# Inspect columns (some files have: 'review', 'sentiment' or similar)
print("Columns:", df.columns.tolist())

# --- STEP 3: Clean and convert to instruction–response format ---
records = []
for _, row in df.iterrows():
    text = str(row.get("review", row.get("text", ""))).strip()
    sentiment = str(row.get("sentiment", "")).strip().capitalize()

    if not text:
        continue

    # Example instruction & output pair
    instruction = f"Translate or explain this Roman Urdu sentence in a helpful tone:\n\n{text}"
    output = f"This Roman Urdu text expresses a {sentiment} sentiment." if sentiment else "This is a Roman Urdu example."

    records.append({"instruction": instruction, "output": output})

print(f"✅ Total usable rows: {len(records)}")

# --- STEP 4: Save as JSONL file ---
with open(output_jsonl, "w", encoding="utf-8") as f:
    for rec in records:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")

print(f"💾 Converted file saved to: {output_jsonl}")
