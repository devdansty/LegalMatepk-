import pandas as pd
import json
import sys

def convert_to_instruction_style(input_csv, output_jsonl):

    # ---------- Load CSV ----------
    try:
        df = pd.read_csv(input_csv)
    except Exception as e:
        print(f"❌ Error reading CSV file: {e}")
        sys.exit(1)

    # ---------- Required Columns ----------
    required_cols = [
        "question_eng", "question_urdu",
        "context_eng", "context_urdu",
        "answer_eng", "answer_urdu"
    ]

    # ---------- Check Missing Columns ----------
    missing = [col for col in required_cols if col not in df.columns]
    if missing:
        print(f"❌ The following required columns are missing: {missing}")
        print("❌ Cannot proceed. Fix your CSV file and try again.")
        sys.exit(1)

    print("✔ All required columns found.")

    dataset = []
    skipped_rows = 0

    # ---------- Process Rows ----------
    for idx, row in df.iterrows():

        # Check if any field is missing, NaN, empty, whitespace-only, or None
        row_invalid = False
        reasons = []

        for col in required_cols:
            val = row[col]

            if pd.isna(val):  # NaN or None
                reasons.append(f"{col} is NaN/None")
                row_invalid = True
            elif isinstance(val, str) and val.strip() == "":
                reasons.append(f"{col} is empty")
                row_invalid = True

        # Skip invalid rows
        if row_invalid:
            skipped_rows += 1
            print(f"⚠️ Skipping row {idx}: {', '.join(reasons)}")
            continue

        # ---------- English Instruction Block ----------
        eng_instruction = {
            "instruction": "Use the provided context to answer the legal question.",
            "input": (
                f"Context: {row['context_eng']}\n\n"
                f"Question: {row['question_eng']}"
            ),
            "output": row["answer_eng"]
        }
        dataset.append(eng_instruction)

        # ---------- Urdu Instruction Block ----------
        urdu_instruction = {
            "instruction": "مہیا کیے گئے سیاق و سباق کی بنیاد پر قانونی سوال کا جواب دیں۔",
            "input": (
                f"سیاق: {row['context_urdu']}\n\n"
                f"سوال: {row['question_urdu']}"
            ),
            "output": row["answer_urdu"]
        }
        dataset.append(urdu_instruction)

    # ---------- Save JSONL ----------
    if len(dataset) == 0:
        print("❌ No valid rows found. JSONL file NOT created.")
        sys.exit(1)

    try:
        with open(output_jsonl, "w", encoding="utf-8") as f:
            for item in dataset:
                f.write(json.dumps(item, ensure_ascii=False) + "\n")

        print(f"\n🎉 Successfully created: {output_jsonl}")
        print(f"✔ Valid samples: {len(dataset)}")
        print(f"⚠️ Skipped rows: {skipped_rows}")

    except Exception as e:
        print(f"❌ Error writing JSONL file: {e}")
        sys.exit(1)


# ---------------- Run Example ----------------
# convert_to_instruction_style("legalUQA.csv", "legalmate_instruct.jsonl")