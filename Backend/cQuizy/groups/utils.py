# groups/utils.py
#? Generate a random invite code (function)

import random
import string

def generate_invite_code():
    """
    Generates an 8-character invite code following a 'digit-letter-digit-letter...'
    pattern. The result does not contain a hyphen.
    Example output: '2k6o1u7p'
    """
    # Define the character sets
    digits = string.digits  # '0123456789'
    letters = string.ascii_lowercase # 'abcdefghijklmnopqrstuvwxyz'
    
    code_parts = []
    # Loop 4 times to get 4 pairs of (digit, letter)
    for _ in range(4):
        code_parts.append(random.choice(digits))
        code_parts.append(random.choice(letters))
        
    # Join the list of characters into a single string
    return "".join(code_parts)