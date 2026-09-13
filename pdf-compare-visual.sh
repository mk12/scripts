#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

usage() {
    cat <<EOS
Usage: $0 PDF1 PDF2 -o OUT [-d DENSITY] [-c COLOR]

Create a visual diff of two PDFs:
  - diff.pdf          : standard pixel diff (changed regions in black)
  - PDF1_diff.pdf     : PDF1 with changed regions highlighted
  - PDF2_diff.pdf     : PDF2 with changed regions highlighted

Options:
  -d DENSITY   Render density in DPI (default: 150)
  -c COLOR     Highlight color (default: red)
EOS
}

die() { echo >&2 "$(basename "$0"): $*"; exit 1; }

density=150
color=red
out=
f=()

while [[ $# -gt 0 ]]; do
    arg=$1
    shift
    case $arg in
        -h|--help) usage; exit ;;
        -d|--density) density=$1; shift ;;
        -c|--color) color=$1; shift ;;
        -o|--out) out=$1; shift ;;
        -*) die "$arg: unexpected flag" ;;
        *) f+=("$arg") ;;
    esac
done

[[ "${#f[@]}" -eq 2 ]] || die "expected two input files"
[[ -n "$out" ]] || die "-o is required"
[[ "$out" = *.* ]] && die "-o should be a directory"

n=()
p=()
for i in 0 1; do
    name=$(basename "${f[$i]}")
    name=${name%%.*}
    n+=("$name")
    p+=("$(magick identify "${f[$i]}" | wc -l)")
done

[[ "${n[0]}" = "${n[1]}" ]] && die "inputs need unique basenames"
[[ "${p[0]}" = "${p[1]}" ]] || die "${f[0]} has ${p[0]} pages; ${f[1]} has ${p[1]} pages"

num_pages=${p[0]}

rm -rf "$out"
mkdir -p "$out/data"
mkdir "$out"/data/{"${n[0]}","${n[1]}",diff,"${n[0]}_highlighted","${n[1]}_highlighted"}

# Render all pages to PNG
for i in 0 1; do
    echo "Saving pages of ${f[$i]}"
    page_idx=0
    while [[ $page_idx -lt "${p[$i]}" ]]; do
        echo "... converting page $((page_idx+1)) of ${p[$i]}"
        magick -density "$density" "${f[$i]}[$page_idx]" -flatten +matte \
            "$out/data/${n[$i]}/$page_idx.png"
        ((page_idx++)) || :
    done
done

echo "Comparing and highlighting differences"
diff_images=()
highlighted_a=()
highlighted_b=()

page_idx=0
while [[ $page_idx -lt $num_pages ]]; do
    echo "... processing page $((page_idx+1)) of $num_pages"

    img_a="$out/data/${n[0]}/$page_idx.png"
    img_b="$out/data/${n[1]}/$page_idx.png"
    mask="$out/data/diff/${page_idx}_mask.png"
    diff_img="$out/data/diff/$page_idx.png"
    out_a="$out/data/${n[0]}_highlighted/$page_idx.png"
    out_b="$out/data/${n[1]}_highlighted/$page_idx.png"

    # 1. Standard pixel diff (original behaviour)
    magick compare -density "$density" -background white \
        "$img_a" "$img_b" "$diff_img" || :
    diff_images+=("$diff_img")

    # 2. Build binary mask: white where pixels differ
    magick "$img_a" "$img_b" \
        -fuzz 5% \
        -compose difference -composite \
        -threshold 0 \
        -morphology Dilate Disk:4 \
        "$mask" || :

    # 3. Overlay semi-transparent highlight onto each original page
    for img in "$img_a" "$img_b"; do
        [[ "$img" == "$img_a" ]] && out_img="$out_a" || out_img="$out_b"
        magick "$img" -colorspace RGB \
            \( "$mask" -colorspace RGB -alpha copy \
                -channel A -evaluate multiply 0.2 +channel \
                -fill "$color" -colorize 100 \
            \) -compose over -composite "$out_img"
    done

    highlighted_a+=("$out_a")
    highlighted_b+=("$out_b")

    ((page_idx++)) || :
done

echo "Generating PDFs"
magick "${diff_images[@]}"    "$out/diff.pdf"
magick "${highlighted_a[@]}"  "$out/${n[0]}.pdf"
magick "${highlighted_b[@]}"  "$out/${n[1]}.pdf"

echo "Done. Output:"
echo "  $out/diff.pdf"
echo "  $out/${n[0]}.pdf"
echo "  $out/${n[1]}.pdf"
