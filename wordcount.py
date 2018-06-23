#!/usr/bin/env python3

from dateutil.parser import parse
import fileinput
import re
import sys


def main():
    date = None
    count = 0
    print("date,word_count")
    for line in fileinput.input():
        line = line.strip()
        if not line:
            continue
        if line.startswith("#"):
            if date:
                print(f"{date},{count}")
                count = 0
            try:
                date = parse(line[1:]).date()
            except ValueError:
                print(f"Failed to parse date: {line}", file=sys.stderr)
                sys.exit(1)
        else:
            count += len(re.findall(r'\b\w+\b', line))
    if date:
        print(f"{date},{count}")
        count = 0


if __name__ == "__main__":
    main()
