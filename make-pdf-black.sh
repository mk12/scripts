#!/bin/bash

set -eufo pipefail

qpdf --qdf --warning-exit-0 "$1" "$1.qdf"
vim -c ':%s/0 0 1 sc/1 sc/ | wq' "$1.qdf"
fix-qdf "$1.qdf" "$1-fixed.qdf"
qpdf --compress-streams=y --object-streams=generate "$1-fixed.qdf" "$1-black.pdf"
rm "$1.qdf" "$1-fixed.qdf"
