#!/usr/bin/env python3
import os
import re
import urllib.request

# Configuration
DICTIONARY_URL = "https://raw.githubusercontent.com/enz/german-wordlist/main/words"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BLACKLIST_PATH = os.path.join(SCRIPT_DIR, "blacklist.txt")
TARGET_PATH = os.path.join(SCRIPT_DIR, "german_scrabble.txt")

# Allowed Scrabble characters (A-Z and German Umlauts Ä, Ö, Ü)
ALLOWED_CHARS_RE = re.compile(r"^[A-ZÄÖÜ]+$")

def main():
    print("Loading blacklist...")
    blacklist = set()
    if os.path.exists(BLACKLIST_PATH):
        with open(BLACKLIST_PATH, "r", encoding="utf-8") as f:
            for line in f:
                word = line.strip().upper()
                if word:
                    blacklist.add(word)
        print(f"Loaded {len(blacklist)} blacklisted words.")
    else:
        print("No blacklist.txt found. Skipping blacklist filtering.")

    # Read existing words if the file exists
    existing_words = set()
    if os.path.exists(TARGET_PATH):
        print("Reading existing dictionary...")
        with open(TARGET_PATH, "r", encoding="utf-8") as f:
            for line in f:
                word = line.strip().upper()
                if word:
                    existing_words.add(word)
        print(f"Loaded {len(existing_words)} existing words.")

    print(f"Downloading new wordlist from {DICTIONARY_URL}...")
    try:
        response = urllib.request.urlopen(DICTIONARY_URL)
        downloaded_content = response.read().decode("utf-8")
    except Exception as e:
        print(f"Error downloading wordlist: {e}")
        return

    print("Processing and merging words...")
    downloaded_words = downloaded_content.splitlines()
    merged_words = set(existing_words)

    added_count = 0
    for raw_word in downloaded_words:
        # Normalize: strip, uppercase, and replace 'ß' with 'SS'
        word = raw_word.strip().upper().replace("ß", "SS")
        
        # Filter 1: must be at least 2 letters long
        if len(word) < 2:
            continue
            
        # Filter 2: must contain only allowed characters
        if not ALLOWED_CHARS_RE.match(word):
            continue
            
        # Filter 3: must not be in blacklist
        if word in blacklist:
            continue
            
        if word not in merged_words:
            merged_words.add(word)
            added_count += 1

    print(f"Added {added_count} new words.")
    print(f"Total words in updated dictionary: {len(merged_words)}")

    print(f"Saving updated dictionary to {TARGET_PATH}...")
    # Sort words alphabetically
    sorted_words = sorted(list(merged_words))
    with open(TARGET_PATH, "w", encoding="utf-8") as f:
        for word in sorted_words:
            f.write(word + "\n")
            
    print("Dictionary update complete!")

if __name__ == "__main__":
    main()
