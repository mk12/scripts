#!/usr/bin/env python3

import argparse
import fileinput
import os
import re
import sys


REPLACEMENTS = {
    r'/\\': '∧',
    r'\\/': '∨',
    r'<>': '≠',
    r'~': '¬',
    r'<->': '↔',
    r'->': '→',
    r'<=': '≤',
    r'>=': '≥',
    r'\\forall': '∀',
    r'\\exists': '∃',
    r'\\fun': 'λ',
    r'\\Gamma': 'Γ',
    r'\\Delta': 'Δ',
    r'\\Theta': 'Θ',
    r'\\Lambda': 'Λ',
    r'\\Xi': 'Ξ',
    r'\\Pi': 'Π',
    r'\\Sigma': 'Σ',
    r'\\Phi': 'Φ',
    r'\\Psi': 'Ψ',
    r'\\Omega': 'Ω',
    r'\\alpha': 'α',
    r'\\beta': 'β',
    r'\\gamma': 'γ',
    r'\\delta': 'δ',
    r'\\epsilon': 'ε',
    r'\\zeta': 'ζ',
    r'\\eta': 'η',
    r'\\theta': 'θ',
    r'\\iota': 'ι',
    r'\\lambda': 'λ',
    r'\\mu': 'μ',
    r'\\xi': 'ξ',
    r'\\pi': 'π',
    r'\\rho': 'ρ',
    r'\\sigma': 'σ',
    r'\\tau': 'τ',
    r'\\phi': 'φ',
    r'\\chi': 'χ',
    r'\\psi': 'ψ',
    r'\\omega': 'ω',
    r'\\0': '₀',
    r'\\1': '₁',
    r'\\2': '₂',
    r'\\3': '₃',
    r'\\4': '₄',
    r'\\5': '₅',
    r'\\6': '₆',
    r'\\7': '₇',
    r'\\8': '₈',
    r'\\9': '₉',
    r'\\S': 'Σ',
    r'\\x': '×',
    r'\\u+': '⊎',
    r'\\N': 'ℕ',
    r'\\Z': 'ℤ',
    r'\\Q': 'ℚ',
    r'\\R': 'ℝ',
    r'\\-1': '⁻¹',
    r'\\tr': '⬝',
    r'\\t': '▸',
    r'\\in': '∈',
    r'\\nin': '∉',
    r'\\i': '∩',
    r'\\un': '∪',
    r'\\sub': '⊂',
    r'\\subeq': '⊆',
    r'\\comp': '∘',
    r'\\empty': '∅',
}


def key_to_re(key):
    def boundary(c):
        return r'\b' if c.isalnum() else ''
    return boundary(key[0]) + key + boundary(key[-1])


def match_to_key(match):
    text = match.group(0)
    escaped = text.replace('\\', '\\\\')
    return REPLACEMENTS[escaped]


def process(in_file, out_file):
    pattern_str = '|'.join(key_to_re(k) for k in REPLACEMENTS)
    pattern = re.compile(pattern_str)

    for line in in_file:
        print(pattern.sub(match_to_key, line), end='', file=out_file)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--save", help="Write new file with extension")
    parser.add_argument("file", help="File to process")
    return parser.parse_args()


def out_filename(args):
    return f"{args.file}.{args.save}"


def main():
    args = parse_args()
    in_file = sys.stdin if args.file == "-" else open(args.file)
    out_file = sys.stdout if not args.save else open(out_filename(args), 'w')
    with in_file, out_file:
        process(in_file, out_file)


if __name__ == '__main__':
    main()
