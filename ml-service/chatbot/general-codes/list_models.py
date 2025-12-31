import requests
import os

api_key = "AIzaSyAILodCtJv7pY8RnjxuMYY-7q8d-ijRseg"
url = f"https://generativelanguage.googleapis.com/v1beta/models?key={api_key}"
response = requests.get(url)
if response.status_code == 200:
    models = response.json().get('models', [])
    for m in models:
        if 'generateContent' in m.get('supportedGenerationMethods', []):
            print(m['name'])
else:
    print(f"Error: {response.status_code} {response.text}")
