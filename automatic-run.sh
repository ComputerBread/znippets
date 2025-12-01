#!/usr/bin/env bash
source "$HOME/.bashrc"
echo "starting: "
date
cd /home/znippets/znippets/
git pull
zigup 0.16.0-dev.1484+d0ba6642b
zig build run -Doptimize=ReleaseFast
