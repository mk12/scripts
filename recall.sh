#!/bin/bash

journal=~/ia/Journal/Journal.txt
line=$(((RANDOM % $(wc -l < $journal)) + 1))
nvim -c "Goyo | $line | set ft=markdown" $journal
