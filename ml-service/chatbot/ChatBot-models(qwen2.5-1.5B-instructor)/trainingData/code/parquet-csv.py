import pandas as pd
import os

base = r"E:\CODE\FYP\application\ml-service\chatbot\ChatBot-models(qwen2.5-1.5B-instructor)\trainingData\raw\DATA"

files = [
    ("legalUQA.parquet", "legalUQA.csv"),
    ("legalUQA_supreme_bilingual.parquet", "legalUQA_supreme_bilingual.csv")
]

for src, dest in files:
    src_path = os.path.join(base, src)
    dest_path = os.path.join(base, dest)
    print(f"\n🔄 Converting: {src_path}")
    
    df = pd.read_parquet(src_path)
    df.to_csv(dest_path, index=False, encoding="utf-8-sig")
    
    print(f"✅ Done → {dest_path}")

print("\n🎯 Conversion complete! Upload the CSVs here ✅")