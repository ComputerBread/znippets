#!/usr/bin/env bash
source "$HOME/.bashrc"
echo "============================================================="
echo "starting: $(date)"
cd /home/znippets/znippets/
git pull
echo "ok"
zigup 0.16.0-dev.1484+d0ba6642b
zig build run -Doptimize=ReleaseFast
