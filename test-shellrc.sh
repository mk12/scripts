#!/bin/bash

for args in -c -lc -ic -lic; do
    for shell in fish bash sh; do
        echo ">" "$shell" "$args" "echo hi"
        "$shell" "$args" "echo hi"
        echo
    done
done
