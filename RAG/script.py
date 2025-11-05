import json
import os
import time
import google.generativeai as genai
from uuid import uuid4

# --- CONFIGURATION ---
os.environ["GEMINI_API_KEY"] = "AIzaSyCuYaIjJTm9exPb8QuCCd5neo9hhgmgpsk"
genai.configure()

INPUT_FILE = "clean_input.json"
OUTPUT_FILE = "structured_data_c.json"
CHUNK_SIZE = 20000  # approx number of characters per chunk
SLEEP_TIME = 2      # seconds between requests to respect rate limits
CHECKPOINT_FILE = "checkpoint.json"

def chunk_text(text, chunk_size=CHUNK_SIZE):
    chunks = []
    start = 0
    while start < len(text):
        end = min(start + chunk_size, len(text))
        split_pos = text.rfind("\n", start, end)
        if split_pos == -1:
            split_pos = text.rfind(".", start, end)
        if split_pos == -1 or split_pos <= start:
            split_pos = end
        chunks.append(text[start:split_pos].strip())
        start = split_pos
    return chunks

def get_gemini_response(text_chunk, file_name):
    model = genai.GenerativeModel(
        model_name="gemini-2.5-flash",
        generation_config={
            "response_mime_type": "application/json",
            "temperature": 0.1
        }
    )
    prompt = f"""
You are an expert legal data parser.
Task: Convert the provided legal text into a structured JSON list you can take reference from previous API calls.

Source File: {file_name}
Input Text:
{text_chunk}

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
        response = model.generate_content(
            prompt,
            request_options={'timeout': 600}
        )
        return json.loads(response.text)
    except Exception as e:
        print(f"❌ Error processing chunk from {file_name}: {e}")
        return []

def load_checkpoint():
    if os.path.exists(CHECKPOINT_FILE):
        with open(CHECKPOINT_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"last_doc": 0, "last_chunk": 0, "structured": []}

def save_checkpoint(last_doc, last_chunk, structured):
    checkpoint_data = {
        "last_doc": last_doc,
        "last_chunk": last_chunk,
        "structured": structured
    }
    with open(CHECKPOINT_FILE, "w", encoding="utf-8") as f:
        json.dump(checkpoint_data, f, indent=4, ensure_ascii=False)

def main():
    print(f"📂 Loading input file {INPUT_FILE}...")
    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        raw_docs = json.load(f)
    print(f"✅ Loaded {len(raw_docs)} documents.")

    checkpoint = load_checkpoint()
    all_structured = checkpoint.get("structured", [])
    last_doc_idx = checkpoint.get("last_doc", 0)
    last_chunk_idx = checkpoint.get("last_chunk", 0)

    for idx, doc in enumerate(raw_docs, 1):
        if idx < last_doc_idx + 1:
            continue  # skip already processed documents

        file_name = doc.get("file_name", "Unknown File")
        text = doc.get("text", "")

        print(f"\n[{idx}/{len(raw_docs)}] Processing: {file_name}")
        chunks = chunk_text(text)
        print(f"  → Split text into {len(chunks)} chunks.")

        for i, chunk in enumerate(chunks, 1):
            if idx == last_doc_idx + 1 and i <= last_chunk_idx:
                continue  # skip already processed chunks

            print(f"    • Sending chunk {i}/{len(chunks)} to Gemini...")
            structured_sections = get_gemini_response(chunk, file_name)
            if structured_sections:
                all_structured.extend(structured_sections)
                print(f"      ✅ Extracted {len(structured_sections)} sections.")
            else:
                print("      ⚠ No sections returned.")

            # Save checkpoint after each chunk
            save_checkpoint(idx, i, all_structured)
            time.sleep(SLEEP_TIME)

    print(f"\n💾 Saving final {len(all_structured)} structured sections to {OUTPUT_FILE}...")
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(all_structured, f, indent=4, ensure_ascii=False)

    # Remove checkpoint after successful completion
    if os.path.exists(CHECKPOINT_FILE):
        os.remove(CHECKPOINT_FILE)

    print("🎉 Done!")

if __name__ == "__main__":
    main()