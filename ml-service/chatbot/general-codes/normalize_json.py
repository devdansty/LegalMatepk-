import json
import re
import math
from collections import Counter

file_path = r'e:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\propertyLaw-instructStyle.json'
output_path = r'e:\CODE\FYP\application\docs\dataForTaining-chatBot\updatedWork\propertyLaw-instructStyle_normalized.json'

def get_tokens(text):
    # Split by non-alphanumeric, keep delimiters
    # Actually, we just want words for vocab.
    return re.findall(r'[a-zA-Z0-9]+', text)

COMMON_WORDS = """
the of and a to in is you that it he was for on are as with his they I at be this have from or one had by word but not what all were we when your can said there use an each which she do how their if will up other about out many then them these so some her would make like him into time has look two more write go see number no way could people my than first water been call who oil its now find long down day did get come made may part over new sound take only little work know place year live me back give most very after things our just name good sentence man think say great where help through much before line right too mean old any same tell boy follow came want show also around form three small set put end does another well large must big even such because turn here why ask went men read need land different home us move try kind hand picture again change off play spell air away animal house point page letter mother answer found study still learn should America world high every near add food between own below country plant last school father keep tree never start city earth eyes light thought head under story saw left don't few while along might close something seem next hard open example begin life always those both paper together got group often run important until children side feet car mile night walk white sea began grow took river four carry state once book hear stop without second late miss idea enough eat face watch far Indian real almost let above girl sometimes mountains cut young talk soon list song being leave family it's body music color stand sun questions fish area mark dog horse birds problem complete room knew since ever piece told usually didn't friends easy heard order red door sure become top ship across today during short better best however low hours black products happened whole measure remember early waves reached listen wind rock space covered fast several hold himself toward five step morning passed vowel true hundred against pattern numeral table north slowly money map farm pulled draw voice seen cold cried plan notice south sing war ground fall king town I'll unit figure certain field travel wood fire upon done English road half ten fly gave box finally wait correct oh quickly person became shown minutes strong verb stars front feel fact inch street decided contain course surface produce building ocean class note nothing rest carefully scientists inside wheels stay green known island week less machine base ago stood plane system behind ran round boat game force brought understand warm common bring explain dry though language shape deep thousands yes clear equation yet government filled heat full hot check object am rule among noun power cannot able six size dark ball material special heavy fine pair circle include built can't matter square syllables perhaps bill felt suddenly test direction center farmers ready anything divided general energy subject Europe moon region return believe dance members picked simple cells paint mind love cause rain exercise eggs train blue wish drop developed window difference distance heart sit sum summer wall forest probably legs sat main winter wide written length reason kept interest arms brother race present beautiful store job edge past sign record finished discovered wild happy beside gone sky grass million west lay weather root instruments meet third months paragraph raised represent soft whether clothes flowers shall teacher held describe drive butt
section title extent saving power court order sale instead division partition suits procedure sharer undertakes buy transferee dwelling representation parties disability reserved bidding shareholders deemed decrees application pending
""".split()

def is_bad_line(line):
    if not line.strip():
        return False
    words = line.split()
    if not words:
        return False
    avg_len = sum(len(w) for w in words) / len(words)
    return avg_len < 1.8

def build_vocab(data):
    counter = Counter()
    
    # Add common words
    for w in COMMON_WORDS:
        counter[w] += 10
        counter[w.lower()] += 10
        counter[w.capitalize()] += 10
        
    for item in data:
        # instruction and output are trusted
        instr = item.get('instruction')
        if not isinstance(instr, str):
            instr = ''
        out = item.get('output')
        if not isinstance(out, str):
            out = ''
            
        text = instr + ' ' + out
        tokens = get_tokens(text)
        for token in tokens:
            counter[token] += 1
            counter[token.lower()] += 1
            
        # Also scan input for GOOD lines
        inp = item.get('input')
        if isinstance(inp, str):
            lines = inp.split('\n')
            for line in lines:
                if not is_bad_line(line):
                    # Good line, add words
                    line_tokens = get_tokens(line)
                    for token in line_tokens:
                        counter[token] += 1
                        counter[token.lower()] += 1
                        
    return counter


class Segmenter:
    def __init__(self, vocab):
        self.vocab = vocab
        self.total = sum(vocab.values())
        self.memo = {}
        
    def cost(self, word):
        # P(word)
        c = self.vocab.get(word, 0)
        if c > 0:
            return -math.log(c / self.total)
        
        # Unknown word cost
        # We prefer longer unknown words over many short ones?
        # Or maybe we assume if it's unknown, it might be a proper noun not in vocab.
        # But if we have "extentandsaving", "extent" and "saving" are in vocab.
        # "andsaving" is not.
        # So known words should be much cheaper.
        return 100 + len(word) # High penalty

    def segment(self, text):
        # text is a string without spaces, e.g. "Title,extentandsaving."
        # We need to split by punctuation first to avoid "Title," being one token
        # But wait, the bad text has spaces around punctuation too: "T i t l e , e x ..."
        # So when we remove spaces, we get "Title,extent..."
        # We should split by non-alphanumeric to get blocks to segment.
        
        # Find all alphanumeric blocks
        blocks = []
        last_pos = 0
        for match in re.finditer(r'[a-zA-Z0-9]+', text):
            start, end = match.span()
            if start > last_pos:
                blocks.append((text[last_pos:start], False)) # Separator
            blocks.append((match.group(), True)) # Word block to segment
            last_pos = end
        if last_pos < len(text):
            blocks.append((text[last_pos:], False))
            
        result = []
        for content, is_word in blocks:
            if is_word:
                # Segment this block
                seg_words = self._segment_block(content)
                result.append(" ".join(seg_words))
            else:
                result.append(content)
        
        # Join everything
        # If we have "Title" " " "," " " "extent" ...
        # The separators are preserved.
        # "Title" + "," + " " + "extent" ...
        # Wait, if the original was "Title,extent", we split into "Title", ",", "extent".
        # result: "Title", ",", "extent".
        # Joined: "Title,extent".
        # We want "Title, extent".
        # But we don't know if there should be a space.
        # However, usually punctuation is followed by space.
        # Let's just join them as is for now. The user asked to remove EXTRA spaces.
        # "Title,extent" is readable. "Title, extent" is better.
        # But "Title , extent" (if I add spaces around everything) is bad.
        
        # Let's try to be smart: add space after comma/period if followed by letter?
        # But let's stick to the core task: fix the words.
        return "".join(result)

    def _segment_block(self, text):
        # Dynamic programming
        n = len(text)
        # dp[i] = (best_cost, last_word_len)
        dp = [(float('inf'), 0)] * (n + 1)
        dp[0] = (0, 0)
        
        # We can optimize by limiting word length
        max_word_len = 20
        
        for i in range(n):
            if dp[i][0] == float('inf'):
                continue
            
            # Try all possible next words
            for length in range(1, min(max_word_len, n - i) + 1):
                word = text[i:i+length]
                
                # Check if word is in vocab (case insensitive match preference)
                # Actually we should try to match the case in vocab if possible, or just use the text as is.
                # For cost calculation, use the best match.
                
                # Try exact match
                c = self.cost(word)
                # Try lower match
                c_lower = self.cost(word.lower())
                
                # If exact match is unknown but lower is known, use lower's cost but keep original case?
                # Or maybe the word IS capitalized (Title).
                
                final_cost = min(c, c_lower)
                
                new_cost = dp[i][0] + final_cost
                if new_cost < dp[i+length][0]:
                    dp[i+length] = (new_cost, length)
                    
        # Backtrack
        words = []
        curr = n
        while curr > 0:
            cost, length = dp[curr]
            if length == 0:
                # Should not happen if we found a path
                # If we didn't find a path (impossible?), treat whole as one word?
                # With our cost function, we always find a path (unknown words allowed).
                break
            word = text[curr-length:curr]
            words.append(word)
            curr -= length
            
        return reversed(words)

def main():
    print("Loading file...")
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    print("Building vocab...")
    vocab = build_vocab(data)
    print(f"Vocab size: {len(vocab)}")
    
    segmenter = Segmenter(vocab)
    
    print("Processing items...")
    count_fixed = 0
    for item in data:
        if 'input' in item:
            lines = item['input'].split('\n')
            new_lines = []
            for line in lines:
                if is_bad_line(line):
                    # Fix it
                    # Remove all spaces
                    no_spaces = line.replace(' ', '')
                    # Segment
                    fixed_line = segmenter.segment(no_spaces)
                    new_lines.append(fixed_line)
                else:
                    new_lines.append(line)
            
            new_input = '\n'.join(new_lines)
            if new_input != item['input']:
                item['input'] = new_input
                count_fixed += 1
                
    print(f"Fixed {count_fixed} items.")
    
    print("Saving file...")
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4, ensure_ascii=False)
    print(f"Saved to {output_path}")

if __name__ == '__main__':
    main()
