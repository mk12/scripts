#!/bin/bash

exec delta \
    --zero-style 'normal' \
    --minus-style 'red' --minus-emph-style 'black red' \
    --plus-style 'green' --plus-emph-style 'black green' \
    --file-style 'bold blue' \
    --file-decoration-style 'bold blue underline'
