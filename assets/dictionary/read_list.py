count = 0
blacklist = set()
try:
    with open("blacklist.txt", "r", encoding="utf-8") as bf:
        for line in bf:
            # Clean whitespace and normalize to lowercase to prevent case issues
            blacklisted_word = line.strip().lower()
            if blacklisted_word:  # Skip empty lines
                blacklist.add(blacklisted_word)
except FileNotFoundError:
    print("Warning: blacklist.txt not found. Proceeding without filtering.")

# 2. Open the source file to read, and a new file to write the filtered results
with (
    open("german_scrabble.txt", "r", encoding="utf-8") as infile,
    open("german_scrabble_filtered.txt", "w", encoding="utf-8") as outfile,
):
    for line in infile:
        word = line.strip()

        # Check if the lowercase version of the word is in our blacklist
        if word.lower() in blacklist:
            continue  # Skip this word entirely and move to the next line

        # Write ALL valid words to the new clean file
        outfile.write(word + "\n")

        # Keep your original console logging logic for 2 and 3 letter words
        if len(word) < 4:
            count += 1
            print(word)

print(
    "<------ Es wurden "
    + str(count)
    + " kurze Wörter (Länge 2 & 3) ausgegeben. ------->"
)
print("Das bereinigte Wörterbuch wurde in 'german_scrabble_filtered.txt' gespeichert.")

