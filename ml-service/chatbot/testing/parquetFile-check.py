import pandas as pd

# 👇 Replace with your file path
file_path = r"E:\CODE\FYP\docs\dataForTaining\legalUQA.parquet"

# Read the file into a DataFrame
df = pd.read_parquet(file_path)

# Show basic info
print("✅ File loaded successfully!")
print("🧱 Columns:", df.columns.tolist())
print("📊 Total rows:", len(df))
print("\n🔹 Preview of first 3 rows:")
print(df.head(3))
