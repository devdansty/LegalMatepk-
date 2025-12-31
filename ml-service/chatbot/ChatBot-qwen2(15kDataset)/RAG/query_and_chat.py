from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pinecone import Pinecone
import os

app = FastAPI()
pc = Pinecone(api_key="YOUR_PINECONE_KEY")
index = pc.Index("YOUR_INDEX_NAME")

class ChatRequest(BaseModel):
    prompt: str

def query_pinecone(user_query: str, top_k: int = 3):
    response = index.query(
        text=user_query, 
        top_k=top_k, 
        include_metadata=True
    )
    
    context_text = ""
    for match in response["matches"]:
        meta = match["metadata"]
        # Building a structured context for the LLM
        context_text += (
            f"--- REFERENCE START ---\n"
            f"SOURCE_NAME: {meta.get('source')}\n"
            f"SECTION_NUMBER: {meta.get('section')}\n"
            f"CHAPTER_TITLE: {meta.get('title')}\n"
            f"LEGAL_CONTENT: {meta.get('text')}\n"
            f"--- REFERENCE END ---\n\n"
        )
    return context_text

@app.post("/generate")
async def generate(request: ChatRequest):
    try:
        user_query = request.prompt
        
        # 2. Retrieve Context
        context = query_pinecone(user_query)
        full_prompt = f"""You are 'LegalMate', an expert legal assistant specialized in Pakistani Law.

INSTRUCTIONS:
1. LANGUAGE: Detect the language of the 'Question'. If it is in Urdu, answer in Urdu. If it is in Roman Urdu, answer in Roman Urdu. If it is in English, answer in English.
2. CITATIONS: You must explicitly cite the Source and Section at the end of your answer. Format: "According to [Source Name], Section [Section Number]..."
3. STRICTNESS: Answer and suggest ONLY using the provided Context . If the information is missing, state that you do not have information on this specific legal matter.

Context:
{context}

Question: 
{user_query}

Answer:"""
        generated_response = qwen_model.generate(full_prompt) 
        
        return {"response": generated_response}
        
    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))