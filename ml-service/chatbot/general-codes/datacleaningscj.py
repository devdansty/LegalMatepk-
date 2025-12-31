import os
import re
import json
from tqdm import tqdm
import pandas as pd

# ======== CONFIG ========
input_folder = r"E:\CODE\FYP\docs\Supreme_court_Of_Pakistan_judgments"   # Folder containing all your .txt files
output_json = r"E:\CODE\FYP\docs\legalUQA_supreme_bilingual.json"
output_parquet = r"E:\CODE\FYP\docs\legalUQA_supreme_bilingual.parquet"
# ========================

data = []

# Regex patterns for section detection
order_pattern = re.compile(r"\b(ORDER|JUDGMENT|DECISION)\b", re.IGNORECASE)
article_pattern = re.compile(r"Article\s*\d+[A-Z]?", re.IGNORECASE)

for file_name in tqdm(os.listdir(input_folder)):
    if not file_name.lower().endswith(".txt"):
        continue

    file_path = os.path.join(input_folder, file_name)
    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
        text = f.read().strip()

    # Clean text and normalize spaces
    text = re.sub(r"\s+", " ", text)

    # Extract title (between heading and first ORDER/JUDGMENT occurrence)
    title_match = re.search(r"IN THE SUPREME COURT OF PAKISTAN(.*?)(ORDER|JUDGMENT)", text, re.IGNORECASE)
    title = title_match.group(1).strip() if title_match else file_name.replace(".txt", "")

    # Extract order or final judgment section
    order_match = order_pattern.split(text)
    order_text = order_match[-1].strip() if len(order_match) > 1 else ""

    # Extract all mentioned constitutional articles
    articles = article_pattern.findall(text)
    article_list = ", ".join(sorted(set(articles))) if articles else "N/A"

    # ------- English version -------
    question_en = (
        f"Question: In the Supreme Court case '{title}', which constitutional articles were discussed and what was the court's decision?"
    )
    answer_en = (
        f"The court made the following observations regarding these articles ({article_list}): {order_text}..."
    )

    # ------- Urdu version -------
    question_ur = (
        f"سوال: سپریم کورٹ کے مقدمہ '{title}' میں کن آئینی دفعات کا ذکر کیا گیا اور عدالت نے کیا فیصلہ دیا؟"
    )
    answer_ur = (
        f"عدالت نے ان دفعات ({article_list}) کے بارے میں یہ فیصلہ دیا: {order_text}..."
    )

    # Add both language pairs
    data.append({"input": question_en, "output": answer_en, "lang": "en"})
    data.append({"input": question_ur, "output": answer_ur, "lang": "ur"})

# Save JSON
os.makedirs(os.path.dirname(output_json), exist_ok=True)
with open(output_json, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

# Save Parquet version (faster for training)
df = pd.DataFrame(data)
df.to_parquet(output_parquet, index=False)

print(f"✅ Done! Created bilingual dataset with {len(data)} entries.")
print(f"📁 JSON saved at: {output_json}")
print(f"📁 Parquet saved at: {output_parquet}")