#!/bin/bash

set -eufo pipefail

usage() {
    cat <<EOS
Usage: $0 PDF1 PDF2 -o OUT [-d DENSITY]

Create a visual diff of two PDFs
EOS
}

die() { echo >&2 "$(basename "$0"): $*"; exit 1; }

density=100
out=
f=()

while [[ $# -gt 0 ]]; do
    arg=$1
    shift
    case $arg in
        -h|--help) usage; exit ;;
        -d|--density) density=$1; shift ;;
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

mkdir "$out"
mkdir "$out"/{"${n[0]}","${n[1]}",diff}

for i in 0 1; do
    echo "Saving pages of ${f[$i]}"
    page_idx=0
    while [[ $page_idx -lt "${p[$i]}" ]]; do
        echo "... converting page $((page_idx+1)) of ${p[$i]}"
        magick -density "$density" "${f[$i]}[$page_idx]" "$out/${n[$i]}/$page_idx.png"
        ((page_idx++)) || :
    done
done

echo "Comparing pages"
page_idx=0
diff_images=()
while [[ $page_idx -lt $num_pages ]]; do
    echo "... comparing page $((page_idx+1)) of $num_pages"
    # shellcheck disable=SC1087
    img=$out/diff/$page_idx.png
    magick compare -density "$density" -background white \
        "$out/${n[0]}/$page_idx.png" "$out/${n[1]}/$page_idx.png" "$img" || :
    diff_images+=("$img")
    ((page_idx++)) || :
done

echo "Generating combined PDF"
magick "${diff_images[@]}" "$out/diff.pdf"
