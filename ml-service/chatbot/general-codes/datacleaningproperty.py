import json
import re
import string

import enchant

# English dictionary
DICT = enchant.Dict("en_US")

def segment_into_words(s: str):
    """
    Given a string of letters with NO spaces (e.g. 'procedurewhensharerundertakestobuy'),
    try to split it into valid English words using a DP (word-break) approach.

    Returns:
        'procedure when sharer undertakes to buy'   (string)
        or None if no good segmentation found.
    """
    s = s.lower()
    n = len(s)
    # dp[i] = list of words that form s[i:], or None
    dp = [None] * (n + 1)
    dp[n] = []  # empty suffix is valid

    # You can tune max word length if you like
    max_word_len = 20

    for i in range(n - 1, -1, -1):
        for j in range(i + 1, min(n, i + max_word_len) + 1):
            word = s[i:j]
            # Only accept if dictionary thinks it's a word
            if DICT.check(word):
                if dp[j] is not None:
                    dp[i] = [word] + dp[j]
                    break

    if dp[0] is None:
        return None

    return " ".join(dp[0])


def fix_spaced_letters_with_dict(text: str) -> str:
    """
    Find sequences like:
        P r o c e d u r e w h e n s h a r e r ...
    i.e. single letters separated by spaces, and try to reconstruct real words.

    We:
      1. Remove spaces from the whole sequence.
      2. Use dictionary-based segmentation.
      3. If successful, replace with 'procedure when sharer ...'.
      4. If not, keep the original sequence as-is.
    """

    # Matches at least 3 letters separated by spaces: A a a form
    pattern = r'(?:[A-Za-z]\s+){2,}[A-Za-z]'

    def replacer(match):
        seq = match.group(0)
        # Remove all spaces to get contiguous letters
        letters_only = re.sub(r'\s+', '', seq)
        segmented = segment_into_words(letters_only)
        if segmented is not None:
            return segmented
        else:
            # Fall back to original spaced sequence if we can't segment
            return seq

    return re.sub(pattern, replacer, text)


def remove_administrator_with_previous_word(text: str) -> str:
    """
    Remove the word BEFORE 'administrator...' and the administrator* token itself.

    Example:
        "law in administrator12345 tells"
    ->     "law tells"
    """
    pattern = r'\b\w+\s+administrator\S*\b'
    return re.sub(pattern, '', text, flags=re.IGNORECASE)


def clean_text(text: str) -> str:
    # Lowercase first
    text = text.lower()

    # Remove administrator+previous word
    text = remove_administrator_with_previous_word(text)

    # Remove punctuation (but keep numbers and letters)
    text = text.translate(str.maketrans("", "", string.punctuation))

    # Fix spaced letters using dictionary-based segmentation
    text = fix_spaced_letters_with_dict(text)

    # Normalize whitespace
    text = re.sub(r'\s+', ' ', text).strip()

    return text


def clean_json(input_file: str, output_file: str):
    with open(input_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    def recursive_clean(obj):
        if isinstance(obj, str):
            return clean_text(obj)
        elif isinstance(obj, list):
            return [recursive_clean(item) for item in obj]
        elif isinstance(obj, dict):
            return {key: recursive_clean(value) for key, value in obj.items()}
        return obj

    cleaned_data = recursive_clean(data)

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(cleaned_data, f, ensure_ascii=False, indent=4)

if __name__ == "__main__":
    input_json = r"E:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\propertyLaw-instructStyle.json"
    output_json = r"E:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\propertyLaw-instructStyle-cleaned.json"

    clean_json(input_json, output_json)
    print("✅ Cleaning completed successfully!")