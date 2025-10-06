import os
import json

# ------------------------------------------------------------
# Step 1: Define file paths
# ------------------------------------------------------------

current_directory = os.path.dirname(os.path.abspath(__file__))

# Main dataset (pdf_data.json)
pdf_data_path = os.path.join(current_directory, '..', 'pdf_data.json')

# File that contains property-related filenames
property_file_list_path = os.path.join(current_directory, '..', 'propertyLawFiles.txt')

# Output path for filtered property laws
output_path = os.path.join(current_directory, '..', 'filtered_property_laws.json')

# ------------------------------------------------------------
# Step 2: Load the dataset (pdf_data.json)
# ------------------------------------------------------------

if not os.path.exists(pdf_data_path):
    raise FileNotFoundError(f"❌ Could not find dataset: {pdf_data_path}")

with open(pdf_data_path, 'r', encoding='utf-8') as f:
    try:
        pdf_data = json.load(f)
    except json.JSONDecodeError as e:
        raise ValueError(f"Error decoding JSON: {e}")

if not isinstance(pdf_data, list):
    raise TypeError("❌ Expected a list of objects in pdf_data.json")

# ------------------------------------------------------------
# Step 3: Load property law file names
# ------------------------------------------------------------

if not os.path.exists(property_file_list_path):
    raise FileNotFoundError(f"❌ Could not find file list: {property_file_list_path}")

# Read file names, clean spaces/newlines, and lowercase for consistent matching
with open(property_file_list_path, 'r', encoding='utf-8') as f:
    property_files = [line.strip().lower() for line in f if line.strip()]

print(f"📋 Loaded {len(property_files)} property law filenames from list.")

# ------------------------------------------------------------
# Step 4: Filter dataset by file name match
# ------------------------------------------------------------

filtered_data = []
matched_files = []

for entry in pdf_data:
    file_name = entry.get("file_name", "").lower()

    # If this file is in the property file list, include it
    if file_name in property_files:
        filtered_data.append(entry)
        matched_files.append(file_name)

# ------------------------------------------------------------
# Step 5: Save filtered data
# ------------------------------------------------------------

with open(output_path, 'w', encoding='utf-8') as outfile:
    json.dump(filtered_data, outfile, indent=4, ensure_ascii=False)

# ------------------------------------------------------------
# Step 6: Print summary
# ------------------------------------------------------------

print("\n✅ Property Law Filtering Completed!")
print(f"📂 Input JSON file: {pdf_data_path}")
print(f"📄 File list used: {property_file_list_path}")
print(f"📁 Output JSON: {output_path}")
print(f"📊 Total entries in dataset: {len(pdf_data)}")
print(f"🏠 Filtered property law entries: {len(filtered_data)}")

if matched_files:
    print("\n📜 Matched Files:")
    print("-" * 50)
    for idx, file in enumerate(matched_files, start=1):
        print(f"{idx}. {file}")
    print("-" * 50)
else:
    print("\n⚠️ No matching files found — check your propertyLawFiles.txt content.")

print("\n✅ Done!\n")