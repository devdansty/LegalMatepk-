import json
import random
import argparse
import requests
import time
import os
from typing import List, Dict

# Configuration
DEFAULT_LOCAL_URL = "http://localhost:8000/generate"
DEFAULT_DOMAIN = "Pakistani Property Law"

def load_json(filepath: str) -> List[Dict]:
    """Loads JSON data from a file."""
    if not os.path.exists(filepath):
        print(f"Warning: Seed file '{filepath}' not found.")
        return []
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_json(data: List[Dict], filepath: str):
    """Saves data to a JSON file."""
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4, ensure_ascii=False)
    print(f"Saved {len(data)} samples to {filepath}")

def construct_prompt(seed_examples: List[Dict], domain: str, num_to_generate: int = 3) -> str:
    """Constructs a few-shot prompt using seed examples."""
    prompt = (
        f"You are an expert assistant specializing in {domain}. "
        "Your task is to generate high-quality synthetic dataset samples for training a chatbot.\n\n"
        "Each sample must be a JSON object with three fields:\n"
        "- \"instruction\": A question or request related to the domain.\n"
        "- \"input\": A realistic scenario, context, or case description.\n"
        "- \"output\": A helpful, accurate, and well-structured response.\n\n"
        "Here are some examples of the desired style and format:\n\n"
    )

    for i, example in enumerate(seed_examples):
        prompt += f"Example {i+1}:\n"
        prompt += json.dumps(example, indent=2, ensure_ascii=False) + "\n\n"

    prompt += (
        f"Now, generate {num_to_generate} NEW and UNIQUE examples following this exact format. "
        "Do not copy the examples above. Create new scenarios relevant to the domain. "
        "Return ONLY a valid JSON list of objects. Do not include markdown formatting like ```json."
    )
    return prompt

def call_local_model(url: str, prompt: str) -> str:
    """Calls the local Qwen model API."""
    payload = {
        "prompt": prompt,
        "max_new_tokens": 1024,
        "temperature": 0.7,
        "top_p": 0.9
    }
    try:
        response = requests.post(url, json=payload)
        response.raise_for_status()
        return response.json().get("response", "")
    except requests.exceptions.RequestException as e:
        print(f"Error calling local model: {e}")
        return ""

def call_openai_api(api_key: str, prompt: str) -> str:
    """Calls the OpenAI API (GPT-4o or similar)."""
    url = "https://api.openai.com/v1/chat/completions"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }
    payload = {
        "model": "gpt-4o",
        "messages": [
            {"role": "system", "content": "You are a helpful assistant that outputs raw JSON."},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.7
    }
    try:
        response = requests.post(url, json=payload, headers=headers)
        response.raise_for_status()
        return response.json()['choices'][0]['message']['content']
    except requests.exceptions.RequestException as e:
        print(f"Error calling OpenAI API: {e}")
        return ""

def call_gemini_api(api_key: str, prompt: str, model_name: str = "gemini-2.0-flash", retries: int = 5) -> str:
    """Calls the Google Gemini API with retries for rate limits."""
    # Using v1beta as it supports newer models like gemini-2.0-flash
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}"
    headers = {"Content-Type": "application/json"}
    payload = {
        "contents": [{"parts": [{"text": prompt}]}]
    }
    
    for attempt in range(retries):
        try:
            response = requests.post(url, json=payload, headers=headers)
            response.raise_for_status()
            return response.json()['candidates'][0]['content']['parts'][0]['text']
        except requests.exceptions.RequestException as e:
            if hasattr(e, 'response') and e.response is not None:
                if e.response.status_code == 429:
                    wait_time = 2 ** (attempt + 1) + random.uniform(0, 1)
                    print(f"  Rate limit hit (429). Retrying in {wait_time:.1f}s...")
                    time.sleep(wait_time)
                    continue
                else:
                    print(f"Error calling Gemini API: {e}")
                    print(f"API Response: {e.response.text}")
                    return ""
            else:
                print(f"Error calling Gemini API: {e}")
                return ""
    
    print("Max retries exceeded for Gemini API.")
    return ""

def parse_response(response_text: str) -> List[Dict]:
    """Attempts to parse the LLM response as JSON."""
    # Clean up potential markdown formatting
    cleaned_text = response_text.strip()
    if cleaned_text.startswith("```json"):
        cleaned_text = cleaned_text[7:]
    if cleaned_text.startswith("```"):
        cleaned_text = cleaned_text[3:]
    if cleaned_text.endswith("```"):
        cleaned_text = cleaned_text[:-3]
    
    try:
        data = json.loads(cleaned_text)
        if isinstance(data, list):
            return data
        elif isinstance(data, dict):
            return [data]
        else:
            print("Response is not a list or dict.")
            return []
    except json.JSONDecodeError:
        print("Failed to parse JSON from response.")
        # print("Raw response snippet:", response_text[:200]) # Commented out to reduce noise
        return []

def main():
    parser = argparse.ArgumentParser(description="Generate synthetic legal data.")
    parser.add_argument("--mode", choices=["local", "openai", "gemini"], default="local", help="Generation mode")
    parser.add_argument("--api_key", help="API Key for OpenAI or Gemini")
    parser.add_argument("--url", default=DEFAULT_LOCAL_URL, help="URL for local model API")
    parser.add_argument("--num_batches", type=int, default=5, help="Number of batches to generate")
    parser.add_argument("--batch_size", type=int, default=3, help="Samples per batch")
    parser.add_argument("--num_seeds", type=int, default=3, help="Number of seed examples to use in prompt")
    parser.add_argument("--sleep_interval", type=int, default=1, help="Seconds to sleep between batches")
    parser.add_argument("--seed_file", required=True, help="Path to seed JSON file")
    parser.add_argument("--output_file", default="synthetic_data_output.json", help="Path to save generated data")
    parser.add_argument("--domain", default=DEFAULT_DOMAIN, help="Domain topic for the prompt (e.g., 'Pakistani Property Law', 'General Legal Knowledge')")
    parser.add_argument("--gemini_model", default="gemini-2.0-flash", help="Gemini model name (e.g., gemini-2.0-flash, gemini-pro)")
    
    args = parser.parse_args()
    
    print(f"Starting generation in {args.mode} mode for domain: '{args.domain}'...")
    
    seed_data = load_json(args.seed_file)
    if not seed_data:
        print("No seed data found. Exiting.")
        return

    all_generated_data = []
    
    # Ensure output directory exists
    output_dir = r"E:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\syntheticGen"
    os.makedirs(output_dir, exist_ok=True)
    
    # Handle output filename
    if not args.output_file.endswith('.json'):
        args.output_file += '.json'
        
    # Full path for output
    output_path = os.path.join(output_dir, args.output_file)
    
    # Load existing output if it exists to append
    if os.path.exists(output_path):
        all_generated_data = load_json(output_path)
        print(f"Loaded {len(all_generated_data)} existing samples from {output_path}")

    for i in range(args.num_batches):
        print(f"Generating batch {i+1}/{args.num_batches} using {args.gemini_model if args.mode == 'gemini' else 'default model'}...")
        
        # Pick random seeds
        seeds = random.sample(seed_data, min(len(seed_data), args.num_seeds))
        prompt = construct_prompt(seeds, args.domain, args.batch_size)
        
        response_text = ""
        if args.mode == "local":
            response_text = call_local_model(args.url, prompt)
        elif args.mode == "openai":
            if not args.api_key:
                print("Error: --api_key is required for openai mode.")
                return
            response_text = call_openai_api(args.api_key, prompt)
        elif args.mode == "gemini":
            if not args.api_key:
                print("Error: --api_key is required for gemini mode.")
                return
            response_text = call_gemini_api(args.api_key, prompt, args.gemini_model)
            
        if response_text:
            new_samples = parse_response(response_text)
            if new_samples:
                print(f"  Generated {len(new_samples)} valid samples.")
                all_generated_data.extend(new_samples)
                # Save progressively
                save_json(all_generated_data, output_path)
            else:
                print("  No valid samples parsed from this batch.")
        
        # Sleep briefly to avoid rate limits or overwhelming local server
        time.sleep(args.sleep_interval)

    print(f"Done! Total samples: {len(all_generated_data)}")

if __name__ == "__main__":
    main()
