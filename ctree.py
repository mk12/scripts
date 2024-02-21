#!/usr/bin/env python3

import argparse
from collections import defaultdict
import sys

parser = argparse.ArgumentParser(description="Convert path:count lines to a tree representation")
parser.add_argument("-L", "--level", type=int)
parser.add_argument("-M", "--minimum", type=int, default=0)
args = parser.parse_args()

factory = lambda: {"count": 0, "children": defaultdict(factory)}
tree = factory()

for line in sys.stdin:
    path, count = line.split(":")
    count = int(count)
    node = tree
    node["count"] += count
    for i, component in enumerate(path.split("/")):
        if i == args.level:
            break
        node = node["children"][component]
        node["count"] += count

def go(indent, path, node):
    count = node["count"]
    if count < args.minimum:
        return
    print(f"{indent}{path} {count}")
    for name, child in sorted(node["children"].items(), key=lambda item: item[1]["count"], reverse=True):
        go(indent + "  ", name, child)

go("", ".", tree)
