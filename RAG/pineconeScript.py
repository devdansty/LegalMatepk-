# -----------------------------
# RAG Pipeline for LegalMate: JSON Data + Pinecone Integrated Embeddings + Qwen2
# -----------------------------

import pinecone
import json

# -----------------------------
# 1️⃣ Initialize Pinecone
# -----------------------------
PINECONE_API_KEY = "pcsk_3yThN5_BLycj6QHmcM4vYK9K7Tsexu985sfTUuoG9J4iH218ykYqQjaD4b8SvNEd343ZhJ"    # Replace with your Pinecone key
PINECONE_ENV = "us-east1"                 # Replace with your Pinecone environment
INDEX_NAME = "legalmate-laws"                # Replace with your Pinecone index name

pinecone.init(api_key=PINECONE_API_KEY, environment=PINECONE_ENV)
index = pinecone.Index(INDEX_NAME)

# -----------------------------
# 2️⃣ Load JSON Data
# -----------------------------
JSON_FILE = "legal_data.json"  # Path to your JSON file

with open(JSON_FILE, "r", encoding="utf-8") as f:
    legal_docs = json.load(f)

print(f"📄 Loaded {len(legal_docs)} legal sections from JSON.")

# -----------------------------
# 3️⃣ Prepare and Upsert Documents
# -----------------------------
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
        "values": text,  # Pinecone integrated embeddings will handle this
        "metadata": metadata
    })

# Upsert into Pinecone in batches of 100 (to avoid large payloads)
BATCH_SIZE = 100
for i in range(0, len(vectors_to_upsert), BATCH_SIZE):
    batch = vectors_to_upsert[i:i + BATCH_SIZE]
    index.upsert(vectors=batch)
    print(f"✅ Upserted batch {i//BATCH_SIZE + 1} ({len(batch)} sections)")

print("🎉 All documents upserted successfully!")

# -----------------------------
# 4️⃣ Function: Query Pinecone
# -----------------------------
def query_pinecone(user_query, top_k=5):
    """
    Search Pinecone for relevant legal sections.
    """
    results = index.query(
        vector=user_query,
        top_k=top_k,
        include_metadata=True
    )

    retrieved_chunks = []
    for match in results['matches']:
        retrieved_chunks.append({
            "id": match['id'],
            "text": match.get('values', ''),
            "metadata": match.get('metadata', {})
        })
    return retrieved_chunks

# -----------------------------
# 5️⃣ Function: Generate Answer with Qwen2
# -----------------------------
def generate_answer(user_query, retrieved_chunks, qwen2_chatbot):
    """
    Construct prompt and get response from fine-tuned Qwen2 1.5B chatbot.
    """
    context_text = ""
    for chunk in retrieved_chunks:
        meta = chunk["metadata"]
        context_text += f"Source: {meta.get('source','')}, Section: {meta.get('section','')}, Title: {meta.get('title','')}\n"
        context_text += f"{chunk['text']}\n\n"

    prompt = f"""
Use the following legal context to answer the question:

{context_text}

Question: {user_query}
Answer:
"""

    response = qwen2_chatbot.generate(prompt)
    return response

# -----------------------------
# 6️⃣ Example Usage
# -----------------------------
if __name__ == "__main__":
    user_question = "What are the steps for filing a civil suit in Pakistan?"

    # Step 1: Retrieve relevant chunks from Pinecone
    chunks = query_pinecone(user_question, top_k=5)
    print("📄 Retrieved chunks:")
    for c in chunks:
        meta = c["metadata"]
        print(f"- {c['id']} | Source: {meta.get('source')} | Section: {meta.get('section')} | Title: {meta.get('title')}")

    # Step 2: Pass chunks + query to Qwen2 chatbot
    class DummyChatbot:
        def generate(self, prompt):
            return "This is a dummy answer. Replace with your Qwen2 call."

    qwen2_chatbot = DummyChatbot()
    answer = generate_answer(user_question, chunks, qwen2_chatbot)
    print("\n💡 Legal Answer:")
    print(answer)
