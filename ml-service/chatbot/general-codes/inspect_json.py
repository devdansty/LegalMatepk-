import json

file_path = r'e:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\propertyLaw-instructStyle.json'

with open(file_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

# Let's look at the first item's input
text = data[0]['input']
print(f"Original text length: {len(text)}")
print(f"Sample text (repr): {repr(text[:500])}")

# Let's find a spaced out line
lines = text.split('\n')
for line in lines:
    if "S E C T I O N S" in line:
        print(f"Spaced line found: {repr(line)}")
        if "  " in line:
            print("Double space found in this line!")
        else:
            print("No double space found in this line.")
        
    if "T i t l e" in line:
        print(f"Another spaced line: {repr(line)}")
        if "  " in line:
             print("Double space found in this line!")
        else:
             print("No double space found in this line.")

