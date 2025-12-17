import pinecone
from config import PINECONE_API_KEY, PINECONE_ENV, INDEX_NAME

# Initialize Pinecone
pinecone.init(api_key=PINECONE_API_KEY, environment=PINECONE_ENV)
index = pinecone.Index(INDEX_NAME)

def query_pinecone(user_query, top_k=5):
    """
    Search Pinecone for top K relevant legal sections.
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

if __name__ == "__main__":
    user_question = "What are the steps for filing a civil suit in Pakistan?"

    # Retrieve top 5 chunks from Pinecone
    chunks = query_pinecone(user_question, top_k=5)
    print("📄 Retrieved chunks:")
    for c in chunks:
        meta = c["metadata"]
        print(f"- {c['id']} | Source: {meta.get('source')} | Section: {meta.get('section')} | Title: {meta.get('title')}")

    # Dummy chatbot class for testing
    class DummyChatbot:
        def generate(self, prompt):
            return "This is a dummy answer. Replace with your Qwen2 call."

    qwen2_chatbot = DummyChatbot()
    answer = generate_answer(user_question, chunks, qwen2_chatbot)
    print("\n💡 Legal Answer:")
    print(answer)
