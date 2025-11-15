import pandas as pd

# 👇 Replace with your file path
file_path = r"E:\CODE\FYP\application\ml-service\chatbot\ChatBot-models(qwen2.5-1.5B-instructor)\trainingData\legalUQA_supreme_bilingual.parquet"

# Read the file into a DataFrame
df = pd.read_parquet(file_path)

# Show basic info
print("✅ File loaded successfully!")
print("🧱 Columns:", df.columns.tolist())
print("📊 Total rows:", len(df))
print("\n🔹 Preview of first 5 rows:")
print(df.head(5))
