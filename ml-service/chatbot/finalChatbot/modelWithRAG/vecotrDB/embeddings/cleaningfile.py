import pandas as pd

# Load CSV with explicit encoding
df = pd.read_csv(r"E:\CODE\FYP\application\ml-service\chatbot\finalChatbot\modelWithRAG\vecotrDB\embeddings\property_laws_chunks.csv", encoding="utf-8", encoding_errors="replace")

# Clean weird encoding artifacts
def clean_text(text):
    if not isinstance(text, str):
        return ""
    return (
        text.encode("latin1", errors="ignore")
        .decode("utf-8", errors="ignore")
        .replace("Â", "")
        .replace("Ã", "")
        .replace("�", "")
        .replace("\u00a0", " ")  # non-breaking spaces
        .strip()
    )

df["text_chunk"] = df["text_chunk"].apply(clean_text)

# Save cleaned file
df.to_csv("property_laws_chunks_clean.csv", index=False, encoding="utf-8")

print("✅ Cleaned CSV saved as property_laws_chunks_clean.csv")