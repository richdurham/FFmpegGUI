import sys

def check_brace_balance(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    stack = []
    line_num = 1
    col_num = 1

    for char in content:
        if char == '{':
            stack.append(('{', line_num, col_num))
        elif char == '}':
            if not stack:
                print(f"Unmatched '}}' at line {line_num}, col {col_num}")
                return False
            stack.pop()

        if char == '\n':
            line_num += 1
            col_num = 1
        else:
            col_num += 1

    if stack:
        for brace, l, c in stack:
            print(f"Unmatched '{brace}' opened at line {l}, col {c}")
        return False

    print(f"Brace balance check passed for {filepath}")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 check_braces.py <file>")
        sys.exit(1)

    if check_brace_balance(sys.argv[1]):
        sys.exit(0)
    else:
        sys.exit(1)
