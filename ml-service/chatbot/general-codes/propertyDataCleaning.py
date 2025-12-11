import json
import re

def clean_text(text):
    if not isinstance(text, str):
        return text

    # ------------------------------
    # 1. Remove PDF page markers
    # ------------------------------
    text = re.sub(r"Page\s+\d+\s+of\s+\d+", "", text, flags=re.IGNORECASE)

    # ------------------------------
    # 2. Remove amendment footnotes / gazette notes
    # ------------------------------
    footnote_patterns = [
        r"\d+\s*Subs\.?.*?(?=Page|\n|\r|\.)",
        r"\d+\s*Ins\.?.*?(?=Page|\n|\r|\.)",
        r"\d+\s*Omitted.*?(?=Page|\n|\r|\.)",
        r"\(see.*?\)",
        r"Gaz\..*?(?=Page|\n|\r|\.)",
        r"Ordinance.*?\d{4}",
        r"\[\s*Omitted.*?\]",
    ]
    for pattern in footnote_patterns:
        text = re.sub(pattern, "", text, flags=re.IGNORECASE | re.DOTALL)

    # ------------------------------
    # 3. Remove underscores + unicode garbage
    # ------------------------------
    text = re.sub(r"_+", " ", text)
    text = re.sub(r"[;•]", "", text)

    # ------------------------------
    # 4. Fix hyphenated PDF split words
    # ------------------------------
    text = re.sub(r"(\w+)\s*-\s*(\w+)", r"\1\2", text)  # hyphens
    text = re.sub(r"(\w+)\s+(\w{2,3})\s+(\w+)", lambda m: (
        m.group(1) + m.group(2) + m.group(3)
        if len(m.group(2)) <= 3 else m.group(0)
    ), text)

    # ------------------------------
    # 5. Remove “administrator + previous word”
    # ------------------------------
    text = re.sub(
        r"\b\w+\s+[^\s]*administrator[^\s]*",
        "",
        text,
        flags=re.IGNORECASE
    )

    # ------------------------------
    # 6. Normalize spacing
    # ------------------------------
    text = re.sub(r"\s+", " ", text).strip()

    return text


def process_json(input_file, output_file):
    with open(input_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    for item in data:
        # Clean instruction
        if "instruction" in item:
            item["instruction"] = clean_text(item["instruction"])

        # Clean input
        if "input" in item:
            item["input"] = clean_text(item["input"])

        # Clean output
        if "output" in item:
            if isinstance(item["output"], str):
                item["output"] = clean_text(item["output"])
            elif isinstance(item["output"], list):
                item["output"] = [
                    clean_text(x) if isinstance(x, str) else x
                    for x in item["output"]
                ]

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

    print(f"✔ Cleaning complete. Cleaned file saved as: {output_file}")

# Example usage:
process_json(r"E:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\propertyLaw-instructStyle_normalized.json", r"E:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\propertyLaw-instructStyle_normalized_cleaned.json")
