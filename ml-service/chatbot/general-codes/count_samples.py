import json
import argparse
import os

# 🔥 Add your file path here
FOLDER_PATH = r"E:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\syntheticGen"

def count_samples(file_path):
    """
    Counts the number of samples in a JSON file and validates instruction-style format.
    Expected format: list of dicts with keys 'instruction', 'input', 'output'.
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        if not isinstance(data, list):
            return {
                "error": "JSON root is not a list",
                "total": 0,
                "valid": 0,
                "invalid": 0
            }

        total_items = len(data)
        valid_count = 0
        missing_keys_count = 0
        required_keys = {'instruction', 'input', 'output'}

        for item in data:
            if isinstance(item, dict) and required_keys.issubset(item.keys()):
                valid_count += 1
            else:
                missing_keys_count += 1

        return {
            "error": None,
            "total": total_items,
            "valid": valid_count,
            "invalid": missing_keys_count
        }

    except Exception as e:
        return {
            "error": str(e),
            "total": 0,
            "valid": 0,
            "invalid": 0
        }


def process_folder(folder_path):
    print(f"\n🔍 Scanning folder: {folder_path}\n")
    json_files = [f for f in os.listdir(folder_path) if f.endswith(".json")]

    if not json_files:
        print("❌ No JSON files found in this folder.")
        return

    for filename in json_files:
        file_path = os.path.join(folder_path, filename)
        print(f"\n📄 File: {filename}")

        result = count_samples(file_path)

        if result["error"]:
            print(f"   ❌ Error: {result['error']}")
        else:
            print(f"   ➤ Total samples: {result['total']}")
            print(f"   ✔ Valid samples: {result['valid']}")
            print(f"   ✖ Invalid samples: {result['invalid']}")


if __name__ == "__main__":
    process_folder(FOLDER_PATH)
