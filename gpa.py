#!/usr/bin/env python3

import sys


GPA_TABLE = [
    (90, 4.0),
    (85, 3.9),
    (80, 3.7),
    (77, 3.3),
    (73, 3.0),
    (70, 2.7),
    (67, 2.3),
    (63, 2.0),
    (60, 1.7),
    (57, 1.3),
    (53, 1.0),
    (50, 0.7),
]


def to_gpa(percent):
    for p, g in GPA_TABLE:
        if percent >= p:
            return g
    return 0


def weighted_gpa(grades_and_credits):
    gpas = [to_gpa(x[0]) for x in grades_and_credits]
    weights = [x[1] for x in grades_and_credits]
    return sum(g * w for g, w in zip(gpas, weights)) / sum(weights)


def main():
    l = []
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        if "," in line:
            g = int(line.split(",")[0])
            c = float(line.split(",")[1])
        else:
            g = int(line)
            c = 0.5
        l.append((g, c))
    print(f"Weighted GPA: {weighted_gpa(l)}")


if __name__ == "__main__":
    main()
