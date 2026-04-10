import sys

def audit_brackets(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    stack = []
    pairs = {')': '(', ']': '[', '}': '{'}
    
    for i, line in enumerate(lines):
        line_num = i + 1
        for char in line:
            if char in '([{':
                stack.append((char, line_num))
            elif char in ')]}':
                if not stack:
                    print(f"Extra closing bracket '{char}' at line {line_num}")
                    continue
                top_char, top_line = stack.pop()
                if top_char != pairs[char]:
                    print(f"Mismatch: found '{char}' at line {line_num} but expected closure for '{top_char}' from line {top_line}")
                    # Try to recover by skipping (not perfect but helpful)
                    pass

    while stack:
        char, line = stack.pop()
        print(f"Unclosed bracket '{char}' at line {line}")

if __name__ == "__main__":
    audit_brackets(sys.argv[1])
