import re
from pathlib import Path
import json

# =========================
# CONFIG
# =========================

MIN_PARA_LENGTH = 40

# Expanded marker sets (optimized for Pakistan SC judgments)
FACT_MARKERS = [
    "arise out of", "impugned judgment", "case record", "instituted",
    "challenged by", "plaintiff", "defendant", "trial court",
    "civil suit", "criminal case", "forum", "background",
    "facts of the case",
    "through this appeal",
    "basis of the suit",
    "filed by",
    "vide judgment",
    "property no.",
    "site plan",
    "situated at",
    "allotment of property",
    "institution of suit"
]

ISSUE_MARKERS = [
    "question arises", "point for determination", "whether",
    "issue involved", "controversy", "for the purpose of jurisdiction",
    "main contention", "question is", "legal question",
    "it is their case",
    "they dispute",
    "preliminary objection",
    "stance is",
    "claimed that",
    "question arises"
]

LOGIC_MARKERS = [
    "we have heard", "we note", "court observed", "relying upon",
    "it will be pertinent", "legal position", "in terms of",
    "has rightly", "we find", "it is evident", "thus",
    "therefore", "considered view", "settled law",
    "we have heard",
    "we are unable to understand",
    "we may note",
    "we need to take into consideration",
    "it is admitted",
    "in this view of the matter",
    "reference can be made",
    "in these circumstances"
]

OUTCOME_MARKERS = [
    "appeal is dismissed", "appeals are dismissed",
    "petition is dismissed", "allowed", "set aside", "disposed of",
    "impugned judgment is upheld", "conviction is maintained",
    "delay is condoned",
    "stands dismissed",
    "appeal is dismissed",
    "this appeal cannot succeed",
    "no order as to costs",
    "application is dismissed",
    "decreed",
    "impugned judgment is maintained"
]

# =========================
# CORE FUNCTIONS
# =========================

def contains_marker(text, markers):
    t = text.lower()
    return any(m in t for m in markers)

def normalize_text(text):
    text = re.sub(r"\s+", " ", text)
    text = text.replace("–", "-")
    return text.strip()

def extract_core_body(full_text):
    lower = full_text.lower()
    if "judgment" in lower:
        idx = lower.find("judgment")
    elif "order" in lower:
        idx = lower.find("order")
    else:
        return None
    return full_text[idx:]

def extract_sections(file_path):
    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
        raw_text = f.read()

    body = extract_core_body(raw_text)
    if not body:
        return None

    body = normalize_text(body)

    # Split into paragraphs
    paragraphs = [p.strip() for p in body.split("\n") if len(p.strip()) > MIN_PARA_LENGTH]

    total = len(paragraphs)

    facts, issues, logic, outcomes = [], [], [], []

    for i, para in enumerate(paragraphs):
        pos_ratio = i / total
        lower = para.lower()

        # Start section → FACTS
        if pos_ratio <= 0.40:
            if contains_marker(lower, FACT_MARKERS):
                facts.append(para)

        # Middle → ISSUES / LOGIC
        elif 0.40 < pos_ratio <= 0.80:
            if contains_marker(lower, ISSUE_MARKERS):
                issues.append(para)
            elif contains_marker(lower, LOGIC_MARKERS):
                logic.append(para)

        # End → OUTCOME
        else:
            if contains_marker(lower, OUTCOME_MARKERS):
                outcomes.append(para)

    return {
        "facts": facts[:5],
        "issues": issues[:5],
        "decision_logic": logic[:6],
        "outcome_principles": outcomes[:3]
    }

# =========================
# BATCH PROCESSOR
# =========================

def process_folder(input_folder, output_file):
    folder = Path(input_folder)
    results = []

    for file in folder.glob("*.txt"):
        data = extract_sections(file)
        if data:
            results.append({
                "file_name": file.name,
                "facts": data["facts"],
                "issues": data["issues"],
                "decision_logic": data["decision_logic"],
                "outcome_principles": data["outcome_principles"]
            })

    with open(output_file, "w", encoding="utf-8") as out:
        json.dump(results, out, ensure_ascii=False, indent=2)

    print(f"✅ Extraction complete. Saved to: {output_file}")

# =========================
# RUN
# =========================

INPUT_FOLDER = r"E:\CODE\FYP\application\docs\temp"
OUTPUT_JSON = r"E:\CODE\FYP\application\docs\temp\extracted_judgments.json"

process_folder(INPUT_FOLDER, OUTPUT_JSON)
