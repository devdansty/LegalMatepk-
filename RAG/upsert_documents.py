
import pinecone
import json
from config import PINECONE_API_KEY, PINECONE_ENV, INDEX_NAME

# Initialize Pinecone
pinecone.init(api_key=PINECONE_API_KEY, environment=PINECONE_ENV)
index = pinecone.Index(INDEX_NAME)

# Load JSON
JSON_FILE = "legal_data.json"

with open(JSON_FILE, "r", encoding="utf-8") as f:
    legal_docs = json.load(f)

print(f"📄 Loaded {len(legal_docs)} legal sections from JSON.")

# Prepare vectors for upserting
vectors_to_upsert = []

for doc in legal_docs:
    doc_id = doc.get("id")
    text = doc.get("text", "")
    metadata = {
        "source": doc.get("source", ""),
        "section": doc.get("section", ""),
        "title": doc.get("title", "")
    }

    vectors_to_upsert.append({
        "id": doc_id,
        "values": text,  # Pinecone integrated embeddings handle this
        "metadata": metadata
    })

# Upsert in batches to avoid large payloads
BATCH_SIZE = 100
for i in range(0, len(vectors_to_upsert), BATCH_SIZE):
    batch = vectors_to_upsert[i:i + BATCH_SIZE]
    index.upsert(vectors=batch)
    print(f"✅ Upserted batch {i//BATCH_SIZE + 1} ({len(batch)} sections)")

print("🎉 All documents upserted successfully!")
