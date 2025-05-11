#!/bin/bash

journal=$(ls $PROJECTS/journal/20*.md | sort -R | head -n1)
line=$(((RANDOM % $(wc -l < "$journal")) + 1))
nvim "$journal:$line"
