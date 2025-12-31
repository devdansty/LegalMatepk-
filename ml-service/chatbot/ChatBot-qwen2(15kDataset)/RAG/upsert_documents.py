import json
from pinecone import Pinecone
from config import PINECONE_API_KEY, INDEX_NAME

pc = Pinecone(api_key=PINECONE_API_KEY)
index = pc.Index(INDEX_NAME)

JSON_FILE = "structured_data.json"
with open(JSON_FILE, "r", encoding="utf-8") as f:
    legal_docs = json.load(f)

print(f"📄 Processing {len(legal_docs)} documents...")
records = []
for doc in legal_docs:
    records.append({
        "_id": str(doc["id"]),
        "text": doc["text"], 
        "source": str(doc.get("source", "unknown")),
        "section": str(doc.get("section", "unknown")),
        "title": str(doc.get("title", "unknown"))
    })
BATCH_SIZE = 90
for i in range(0, len(records), BATCH_SIZE):
    batch = records[i : i + BATCH_SIZE]
    index.upsert_records(namespace="legal-namespace", records=batch)
    print(f"✅ Upserted batch {i // BATCH_SIZE + 1}")

print("🎉 Successfully uploaded and embedded to Pinecone!")