import requests
import json
import os
import time

# --- CONFIGURATION ---
OPENROUTER_API_KEY = "your_key_here"
INPUT_FILE = "largdata.json"
OUTPUT_FILE = "structured_data_c.json"
CHECKPOINT_FILE = "checkpoint.json"
MODEL_ID = "xiaomi/mimo-v2-flash:free"

def get_openrouter_response(text, file_name):
    # Your original exact prompt logic
    prompt = f"""
You are an expert legal data parser.
Task: Convert the provided legal text into a structured JSON list.

Source File: {file_name}
Input Text:
{text}

Requirements:
1. Extract every legal section as a separate object.
2. "source": Name of the Ordinance/Act.
3. "section": The section number (e.g., "2", "3", "5A").
4. "id": Generate a unique ID (e.g., based on Act abbreviation + section number).
5. "title": The title of the section.
6. "text": The full text of the section, cleaned of page numbers and headers.

Output Schema (Strict JSON List):
[
  {{
    "id": "string",
    "source": "string",
    "section": "string",
    "title": "string",
    "text": "string"
  }}
]
"""
    try:
        response = requests.post(
            url="https://openrouter.ai/api/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                "Content-Type": "application/json",
                "HTTP-Referer": "http://localhost:3000", # Required for OpenRouter
                "X-Title": "LegalMate-Parser"
            },
            data=json.dumps({
                "model": MODEL_ID,
                "messages": [{"role": "user", "content": prompt}],
                "include_reasoning": True, # Xiaomi reasoning mode
                "response_format": {"type": "json_object"}
            }),
            timeout=300 # Reasoning takes time
        )
        
        resp_data = response.json()
        
        # Check for API Errors
        if "error" in resp_data:
            print(f"   ❌ API Error: {resp_data['error'].get('message')}")
            return None

        content = resp_data['choices'][0]['message']['content']
        # Remove potential markdown clutter
        clean_content = content.replace("```json", "").replace("```", "").strip()
        return json.loads(clean_content)
        
    except Exception as e:
        print(f"   ❌ Network/Parsing Error: {e}")
        return None

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

    print(f"🔄 Checkpoint: {len(processed_files)} files already processed.")
    
    total_to_process = len(raw_docs)
    
    for index, doc in enumerate(raw_docs):
        file_name = doc.get("file_name", f"Unknown_{index}")
        
        # SKIP if already done
        if file_name in processed_files:
            continue

        text = doc.get("text", "")
        print(f"📄 [{index + 1}/{total_to_process}] Processing: {file_name}...")

        structured_data = get_openrouter_response(text, file_name)

        if structured_data:
            # Add results (handling if model returns a single dict or a list)
            if isinstance(structured_data, list):
                all_results.extend(structured_data)
            else:
                all_results.append(structured_data)
            
            # Update Checkpoint
            processed_files.append(file_name)
            save_checkpoint({"processed_files": processed_files, "results": all_results})
            print(f"   ✅ Success! Saved to checkpoint.")
        else:
            print(f"   ⚠️ Failed to process {file_name}. Skipping for now.")

        # Rate limit safety for free tier
        time.sleep(2)

    # Final Export
    print(f"\n💾 Finalizing... Saving {len(all_results)} sections to {OUTPUT_FILE}")
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(all_results, f, indent=4, ensure_ascii=False)

    print("🎉 All documents processed successfully!")

if __name__ == "__main__":
    main()