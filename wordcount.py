#!/usr/bin/env python3

import argparse
import csv
from dateutil.parser import parse
import re
import sys


def entries(input):
    date = None
    entry = ""
    for line in input:
        if not line.strip():
            continue
        if line.startswith("#"):
            if date is not None:
                yield date, entry
                entry = ""
            try:
                date = parse(line[1:]).date()
            except ValueError:
                print(f"Failed to parse date: {line}", file=sys.stderr)
                sys.exit(1)
        else:
            entry += line
    if date is not None:
        yield date, entry


def write_counts(output, input, regex):
    print("date,count", file=output)
    for date, entry in entries(input):
        count = len(re.findall(regex, entry))
        print(f"{date},{count}", file=output)


def parse_args():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument(
        "input", metavar="F", help="Journal input file")
    parser.add_argument(
        "-o", "--output", default="wordcount.csv", help="Output CSV file")
    parser.add_argument(
        "-r", "--regex", default=r'\b\w+\b',
        help="Count occurrences of regex per day")
    return parser.parse_args()


def main():
    args = parse_args()
    regex = re.compile(args.regex, re.IGNORECASE)
    print(f"Using regex: {regex}")
    with open(args.input) as input_file, open(args.output, "w") as output_file:
        write_counts(output_file, input_file, regex)


if __name__ == "__main__":
    main()
