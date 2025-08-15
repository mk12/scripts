#!/usr/bin/env python3

from argparse import ArgumentParser
import re

parser = ArgumentParser(description="make an SVG grid of NxM cells")
parser.add_argument("dim", metavar="WxH", default="10", help="grid cells as W or WxH")
parser.add_argument("-s", "--scale", type=int, default=10, help="cell pixel size")
parser.add_argument("-w", "--stroke", type=int, default=1, help="stroke width")
parser.add_argument("-f", "--font", type=int, default=15, help="label font size")
parser.add_argument("-g", "--gap", default="5x9", help="label gap")
parser.add_argument("-m", "--margin", type=int, default=1, help="container margin")
parser.add_argument("--debug", action="store_true", help="debug container dimensions")
parser.add_argument("--chart", help="knitting symbol chart")
args = parser.parse_args()

def two(s):
    return [int(n) for n in (s if "x" in s else f"{s}x{s}").split("x")]

x, y = two(args.dim)
s = args.scale
w = x * s
h = y * s
f = args.font
gw, gh = two(args.gap)
lw = f * 0.6 * (1 if y < 10 else 2)
lh = f * 0.75
m = args.margin
fw = w + gw + lw + m
fh = h + gh + lh + m

stroke_width = "" if args.stroke == 1 else f' stroke-width="{args.stroke}"'

grid_d = f"M0 0l{w} 0l0 {h}l-{w} 0Z"
for i in range(1, x):
    grid_d += f"M{i*s} 0l0 {h}"
for i in range(1, y):
    grid_d += f"M0 {i*s}l{w} 0"

labels = []
for i in range(x):
    labels.append(f'<text x="{(i+0.5)*s:g}" y="{fh-m:g}">{x-i}</text>')
for i in range(y):
    labels.append(f'<text x="{w+lw/2+gw:g}" y="{(i+0.5)*s+lh/2:g}">{y-i}</text>')

marks = ""
if args.chart:
    with open(args.chart) as file:
        chart = file.read().strip().split("\n")
    filled = ""
    stroked = ""
    lines = ""
    bg = ""
    for i in range(x):
        for j in range(y):
            cell = chart[j][i]
            match cell:
                case ".": # knit
                    continue
                case "x": # purl
                    # lines += f"M{(i+0.25)*s:g} {(j+0.5)*s:g}l{s/2:g} 0"
                    filled += f'<circle cx="{(i+0.5)*s:g}" cy="{(j+0.5)*s:g}" r="{s*0.15:g}"/>\n'
                case "#": # blacked out
                    filled += f'<rect x="{i*s:g}" y="{j*s:g}" width="{s:g}" height="{s:g}" opacity="0.5"/>\n'
                case "o": # yo
                    stroked += f'<circle cx="{(i+0.5)*s:g}" cy="{(j+0.5)*s:g}" r="{s*0.2:g}"/>\n'
                case "/": # k2tog
                    lines += f"M{(i+0.3)*s:g} {(j+0.7)*s:g}l{s*0.4:g} {-s*0.4:g}"
                case "\\": # ssk
                    lines += f"M{(i+0.7)*s:g} {(j+0.7)*s:g}l{-s*0.4:g} {-s*0.4:g}"
                case "m": # k3tog
                    lines += f"M{(i+0.3)*s:g} {(j+0.7)*s:g}l{s*0.2:g} {-s*0.2:g}l{s*0.2:g} {s*0.2:g}m{-s*0.2:g} 0l0 {-s*0.2:g}l{s*0.2:g} {-s*0.2:g}"
                case "w": # kfbf
                    lines += f"M{(i+0.3)*s:g} {(j+0.3)*s:g}l{s*0.2:g} {s*0.4:g}l{s*0.2:g} {-s*0.4:g}m{-s*0.2:g} 0l0 {s*0.4:g}"
                case "%": # k2tog, knit in first st
                    lines += f"M{(i+0.3)*s:g} {(j+0.7)*s:g}l{s*0.4:g} {-s*0.4:g}l0 {s*0.4:g}"
                    # filled += f'<circle cx="{(i+0.675)*s:g}" cy="{(j+0.675)*s:g}" r="{s*0.05:g}"/>\n'
                case _:
                    raise Exception(f"unexpected chart symbol '{cell}'")
            bg += f"M{i*s:g} {j*s:g}l{s:g} 0l0 {s:g}l-{s:g} 0z"
    # filled += f'<path fill="#b0b0b040" d="{bg}"/>\n'
    if stroked:
        lines = f'<path d="{lines}"/>'
        stroked = f"""\
<g fill=\"none\" stroke=\"currentColor\">
{stroked}
{lines}
</g>
"""
    elif lines:
        stroked = f'<path fill=\"none\" stroke=\"currentColor\" d="{lines}"/>'
    marks = f"""\
{filled}
{stroked}
"""

debug_rect = ""
if args.debug:
    debug_rect = """\
<rect x="-1000" y="-1000" width="2000" height="2000" fill="#ff000022"/>
"""

svg = f"""\
<svg viewBox="-{m} -{m} {fw+m:g} {fh+m:g}" width="{fw+m:g}" height="{fh+m:g}" fill="currentColor">
{debug_rect}{marks}<path fill="none" stroke="currentColor"{stroke_width} d="{grid_d}"/>
<g font-size="{f}px" font-family="Arial" text-anchor="middle">
{"\n".join(labels)}
</g>
</svg>\
"""

print(re.sub(r"\n+", "\n", svg))
