#!/bin/bash

exec delta \
    --24-bit-color never \
    --hunk-header-style 'normal' \
    --zero-style 'normal' \
    --minus-style 'red' --minus-emph-style 'black red' \
    --plus-style 'green' --plus-emph-style 'black green' \
    --file-style 'bold blue' \
    --file-decoration-style 'bold blue underline' \
    "$@"
