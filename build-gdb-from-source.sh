#!/bin/bash

set -eufo pipefail

readonly gdb=gdb-13.2
readonly python=python3.11

# sudo apt-get install libzstd-dev
cd "$PROJECTS"
curl -LO https://ftp.gnu.org/gnu/gdb/$gdb.tar.xz
xz -d $gdb.tar.xz
tar xf $gdb.tar
rm $gdb.tar
cd $gdb
./configure --prefix="$HOME/.local" --with-python=$python --with-zstd
make -j72
make install
