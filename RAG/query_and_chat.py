from pinecone import Pinecone
from config import PINECONE_API_KEY, INDEX_NAME

# Initialize Pinecone
pc = Pinecone(api_key=PINECONE_API_KEY)
index = pc.Index(INDEX_NAME)

def query_pinecone(user_query: str, top_k: int = 5):
    """
    Query Pinecone using integrated embeddings.
    """
    response = index.query(
        text=user_query,
        top_k=top_k,
        include_metadata=True
    )

    retrieved_chunks = []

    for match in response["matches"]:
        retrieved_chunks.append({
            "id": match["id"],
            "text": match["metadata"].get("text", ""),  # stored text
            "metadata": match["metadata"]
        })

    return retrieved_chunks


def generate_answer(user_query, retrieved_chunks, qwen2_chatbot):
    """
    Construct legal prompt and call Qwen2.
    """
    context = ""

    for chunk in retrieved_chunks:
        meta = chunk["metadata"]
        context += (
            f"Source: {meta.get('source')}\n"
            f"Section: {meta.get('section')}\n"
            f"Title: {meta.get('title')}\n"
            f"Text: {chunk['text']}\n\n"
        )

    prompt = f"""
You are a legal assistant for Pakistani law.

Answer the question using ONLY the context below.
If the answer is not found, say so clearly.

Context:
{context}

Question:
{user_query}

Answer:
"""

    return qwen2_chatbot.generate(prompt)


# ---- Local test ----
if __name__ == "__main__":
    user_question = "What is the Enforcement of Shariah Act, 1991?"

    chunks = query_pinecone(user_question)

    print("📄 Retrieved sections:")
    for c in chunks:
        meta = c["metadata"]
        print(f"- {c['id']} | {meta.get('source')} | Section {meta.get('section')}")

    # Dummy chatbot for now
    class DummyChatbot:
        def generate(self, prompt):
            return "Dummy response. Replace with Qwen2 inference."

    chatbot = DummyChatbot()
    answer = generate_answer(user_question, chunks, chatbot)

    print("\n💡 Answer:")
    print(answer)
