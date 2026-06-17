import random

def random_32bit_word_hex():
    return format(random.getrandbits(32), '08x')

def generate_line(words_per_line=8):
    return "".join(random_32bit_word_hex() for _ in range(words_per_line))

def generate_file(num_lines=16, words_per_line=8, filename="tb/mem_data.txt"):
    with open(filename, "w") as f:
        for _ in range(num_lines):
            f.write(generate_line(words_per_line) + "\n")

if __name__ == "__main__":
    num_lines = 2 ** 18
    generate_file(num_lines=num_lines)
    print(f"Generated {num_lines} lines of 8x32-bit hex words in tb/mem_data.txt")
