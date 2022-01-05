#!/bin/bash

set -eufo pipefail

xattr -r -d com.apple.quarantine "$@"
