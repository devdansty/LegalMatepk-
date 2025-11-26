import requests
import argparse

def list_models(api_key):
    url = f"https://generativelanguage.googleapis.com/v1beta/models?key={api_key}"
    try:
        response = requests.get(url)
        response.raise_for_status()
        models = response.json().get('models', [])
        print(f"Found {len(models)} models:")
        for model in models:
            if 'generateContent' in model.get('supportedGenerationMethods', []):
                print(f" - {model['name']} (Supported)")
            else:
                print(f" - {model['name']} (Not supported for generateContent)")
    except Exception as e:
        print(f"Error listing models: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--api_key", required=True)
    args = parser.parse_args()
    list_models(args.api_key)
