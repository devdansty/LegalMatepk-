import pandas as pd
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient
from qdrant_client.models import PointStruct, VectorParams, Distance
import uuid

# ==============================
# STEP 1: CONFIGURATION
# ==============================
QDRANT_URL = "https://51a42850-e13a-41b9-9d00-103bc99ae2ee.eu-west-2-0.aws.cloud.qdrant.io:6333"  # e.g., https://abcd1234-xyz.aws.cloud.qdrant.io
QDRANT_API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3MiOiJtIn0._3afSnrLwBm8Enc64ME6qsbNpgVgeVIgIvzYXscQ4JU"
COLLECTION_NAME = "property_laws-fyp-chatbot-embeddings"

# ==============================
# STEP 2: LOAD CHUNKS
# ==============================
df = pd.read_csv(r"E:\CODE\FYP\application\ml-service\chatbot\finalChatbot\modelWithRAG\vecotrDB\embeddings\property_laws_chunks_clean.csv")

if "text_chunk" not in df.columns:
    raise ValueError("CSV must contain a 'text_chunk' column")

texts = df["text_chunk"].tolist()
chunk_ids = df["chunk_id"].tolist()

# ==============================
# STEP 3: LOAD EMBEDDING MODEL
# ==============================
model = SentenceTransformer("all-MiniLM-L6-v2")
print("🔢 Generating embeddings...")
embeddings = model.encode(texts, show_progress_bar=True)

# ==============================
# STEP 4: CONNECT TO QDRANT
# ==============================
client = QdrantClient(url=QDRANT_URL, api_key=QDRANT_API_KEY)

# Create collection if it doesn't exist
if COLLECTION_NAME not in [c.name for c in client.get_collections().collections]:
    client.create_collection(
        collection_name=COLLECTION_NAME,
        vectors_config=VectorParams(size=embeddings.shape[1], distance=Distance.COSINE)
    )
    print(f"✅ Created new collection: {COLLECTION_NAME}")
else:
    print(f"⚠️ Collection '{COLLECTION_NAME}' already exists, adding vectors to it.")

# ==============================
# STEP 5: UPLOAD EMBEDDINGS
# ==============================
print("📤 Uploading embeddings to Qdrant Cloud...")

points = [
    PointStruct(
        id=str(uuid.uuid4()),
        vector=embeddings[i],
        payload={
            "chunk_id": chunk_ids[i],
            "text": texts[i]
        }
    )
    for i in range(len(embeddings))
]

# Batch upload (in chunks to avoid timeouts)
BATCH_SIZE = 100
for i in range(0, len(points), BATCH_SIZE):
    batch = points[i:i + BATCH_SIZE]
    client.upsert(collection_name=COLLECTION_NAME, points=batch)
    print(f"✅ Uploaded {i + len(batch)} / {len(points)} vectors")

print("🎉 All embeddings successfully stored in Qdrant Cloud!")