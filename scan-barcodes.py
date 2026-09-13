#!/usr/bin/env uv run

# /// script
# dependencies = ["zxing-cpp", "pillow"]
# ///

import argparse
import zxingcpp
from PIL import Image

parser = argparse.ArgumentParser(description="Scan barcode from image file")
parser.add_argument("path", metavar="PATH")
args = parser.parse_args()

image = Image.open(args.path)
results = zxingcpp.read_barcodes(image)

for r in results:
    print(f"Found {r.format}:")
    # Use repr since it might have carriage returns or other weird characters.
    print(repr(r.text))
