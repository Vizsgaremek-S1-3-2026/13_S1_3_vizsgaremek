
import re

file_path = r'c:\Users\molnarkaroly\Documents\GitHub\13_S1_3_vizsgaremek\Frontend\cQuizy\cquizy\lib\group_page.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace .withOpacity(val) with .withValues(alpha: val)
new_content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)

# Check if changes were made
if content != new_content:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Replacements made.")
else:
    print("No replacements needed.")
