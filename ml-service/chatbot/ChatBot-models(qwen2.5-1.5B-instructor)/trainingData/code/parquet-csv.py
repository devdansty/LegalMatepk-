import pandas as pd
import os

base = r"E:\CODE\FYP\application\docs\dataForTaining-chatBot"

files = [
   ("legalUQA.parquet", "legalUQA.csv")
]

for src, dest in files:
    src_path = os.path.join(base, src)
    dest_path = os.path.join(base, dest)
    print(f"\n🔄 Converting: {src_path}")
    
    df = pd.read_parquet(src_path)
    df.to_csv(dest_path, index=False, encoding="utf-8-sig")
    
    print(f"✅ Done → {dest_path}")

print("\n🎯 Conversion complete! Upload the CSVs here ✅")