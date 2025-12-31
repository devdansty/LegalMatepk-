import json
import random

# Utility: load JSON file (list of objects)
def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)   # json file always contains a list at top level

# ---------- LOAD ALL DATASETS (original + synthetic) ---------- #

# Property
property_original = load_json(r"E:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\propertyLaw-instructStyle_normalized_cleaned.json")
property_synthetic = load_json(r"E:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\syntheticGen\syntheticDataForProperty.json")
property_data = property_original + property_synthetic

# Supreme Court
sc_original = load_json(r"E:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\scj.json")
sc_synthetic = load_json(r"E:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\syntheticGen\syntheticDataForSCJ.json")
sc_data = sc_original + sc_synthetic

# Legal UQA
legal_original = load_json(r"E:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\Legal-QAD-instruct.json")
legal_synthetic = load_json(r"E:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\syntheticGen\syntheticDataForLegalQA.json")
legal_data = legal_original + legal_synthetic

# General UQA
general_original = load_json(r"E:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\General-UQAD.json")
general_synthetic = load_json(r"E:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\syntheticGen\syntheticDataForUQA.json")
general_data = general_original + general_synthetic


# ---------- CONFIGURATION ---------- #

TOTAL = 5000

n_property = int(TOTAL * 0.60)  # 3000
n_sc = int(TOTAL * 0.25)        # 1250
n_legal = int(TOTAL * 0.10)     # 500
n_general = int(TOTAL * 0.05)   # 250


# ---------- RANDOM RESAMPLING FUNCTION (DUPLICATES INSERTED RANDOMLY) ---------- #

def random_resample(data, target_size):
    """
    Randomizes, oversamples, and prevents duplicates from being grouped.
    """
    result = []
    base = data.copy()
    random.shuffle(base)  # mix original + synthetic

    while len(result) < target_size:
        batch = base.copy()
        random.shuffle(batch)  # reshuffle each time
        result.extend(batch)

    # Trim
    result = result[:target_size]

    # Final shuffle to avoid adjacent duplicates
    random.shuffle(result)

    return result


# ---------- PREPARE FINAL CATEGORY DATA ---------- #

final_property = random_resample(property_data, n_property)
final_sc = random_resample(sc_data, n_sc)
final_legal = random_resample(legal_data, n_legal)
final_general = random_resample(general_data, n_general)

# ---------- COMBINE WHILE KEEPING CATEGORY ORDER ---------- #

final_dataset = final_property + final_sc + final_legal + final_general


# ---------- SAVE TO JSONL ---------- #

output_path = r"E:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\finalFile\final_dataset.jsonl"

with open(output_path, "w", encoding="utf-8") as f:
    for item in final_dataset:
        f.write(json.dumps(item, ensure_ascii=False) + "\n")

print("✔ final_dataset.jsonl created with exactly", len(final_dataset), "samples!")