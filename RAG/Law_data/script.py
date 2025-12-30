import requests
import json
import os
import time

# --- CONFIGURATION ---
OPENROUTER_API_KEY = "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"
INPUT_FILE = "largdata.json"
OUTPUT_FILE = "structured_data_b.json"
CHECKPOINT_FILE = "checkpoint.json"
MODEL_ID = "mistralai/devstral-2512:free"

def get_multi_turn_extraction(full_text, file_name):
    # This is your original exact prompt logic, used for the first call
    original_prompt_requirements = """
Requirements:
1. Extract every legal section as a separate object.
2. "source": Name of the Ordinance/Act.
3. "section": The section number (e.g., "2", "3", "5A").
4. "id": Generate a unique ID (e.g., based on Act abbreviation + section number).
5. "title": The title of the section.
6. "text": The full text of the section, cleaned of page numbers and headers.

Output Schema (Strict JSON List):
[
  {
    "id": "string",
    "source": "string",
    "section": "string",
    "title": "string",
    "text": "string"
  }
]
"""

    messages = [
        {
            "role": "system",
            "content": "You are an expert legal data parser. Your task is to extract legal sections into a structured JSON list following strict metadata rules."
        },
        {
            "role": "user",
            "content": f"Source File: {file_name}\nInput Text:\n{full_text}\n\nTask: Extract the NEXT 25 legal sections keeping the correct context of whole document .\n{original_prompt_requirements}"
        }
    ]

    all_document_results = []
    batch_count = 1

    while True:
        try:
            print(f"      📡 Requesting Batch {batch_count}...")
            response = requests.post(
                url="https://openrouter.ai/api/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": "http://localhost:3000",
                    "X-Title": "LegalMate-Parser"
                },
                data=json.dumps({
                    "model": MODEL_ID,
                    "messages": messages,
                    "response_format": {"type": "json_object"},
                    "include_reasoning": False 
                }),
                timeout=600
            )
            
            resp_data = response.json()
            if "error" in resp_data:
                print(f"      ❌ API Error: {resp_data['error'].get('message')}")
                break

            content = resp_data['choices'][0]['message']['content']
            
            # --- CLEAN & PARSE ---
            clean_content = content.replace("```json", "").replace("```", "").strip()
            data = json.loads(clean_content)
            batch_list = data if isinstance(data, list) else next(iter(data.values()))

            if not batch_list or len(batch_list) == 0:
                print("      🏁 No more sections found.")
                break

            all_document_results.extend(batch_list)
            print(f"      ✅ Batch {batch_count} success! (+{len(batch_list)} sections)")

            # --- CONTEXT THREADING ---
            messages.append({"role": "assistant", "content": content})
            
            # We repeat the core requirement in every follow-up so it doesn't forget the format
            messages.append({
                "role": "user", 
                "content": f"Excellent. Now extract the NEXT 10 legal sections. Remember to keep the 'source' correct and maintain the strict JSON schema:\n{original_prompt_requirements}\nIf finished, return an empty list []."
            })
            
            batch_count += 1
            time.sleep(4) # Slightly longer sleep to be safe with free tier

        except Exception as e:
            print(f"      ❌ Error in Batch {batch_count}: {e}")
            break
            
    return all_document_results

def load_checkpoint():
    if os.path.exists(CHECKPOINT_FILE):
        with open(CHECKPOINT_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"processed_files": [], "results": []}

def save_checkpoint(checkpoint_data):
    with open(CHECKPOINT_FILE, "w", encoding="utf-8") as f:
        json.dump(checkpoint_data, f, indent=4, ensure_ascii=False)

def main():
    print(f"📂 Loading input file {INPUT_FILE}...")
    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        raw_docs = json.load(f)

    checkpoint = load_checkpoint()
    processed_files = checkpoint["processed_files"]
    all_results = checkpoint["results"]

    for index, doc in enumerate(raw_docs):
        file_name = doc.get("file_name", f"Unknown_{index}")
        if file_name in processed_files: continue

        text = doc.get("text", "")
        print(f"📄 [{index + 1}/{len(raw_docs)}] Processing: {file_name}...")

        file_sections = get_multi_turn_extraction(text, file_name)

        if file_sections:
            all_results.extend(file_sections)
            processed_files.append(file_name)
            save_checkpoint({"processed_files": processed_files, "results": all_results})
            print(f"   🎉 File {file_name} completed. Saved {len(file_sections)} sections.")
        else:
            print(f"   ⚠️ Failed to extract any data from {file_name}.")

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(all_results, f, indent=4, ensure_ascii=False)
    print("\n🎉 MISSION COMPLETE! All documents processed.")

if __name__ == "__main__":
    main()