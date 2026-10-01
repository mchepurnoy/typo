#!/bin/bash
# Renders Support/AppIcon.svg into Support/AppIcon.icns (every size macOS asks for).
# Usage: scripts/build-icon.sh
set -euo pipefail
cd "$(dirname "$0")/.."

WORK=build/icon
ICONSET=$WORK/AppIcon.iconset
rm -rf "$WORK"
mkdir -p "$ICONSET"
swiftc -O scripts/render-svg.swift -o "$WORK/render-svg"

for size in 16 32 128 256 512; do
  "$WORK/render-svg" Support/AppIcon.svg "$ICONSET/icon_${size}x${size}.png" "$size"
  "$WORK/render-svg" Support/AppIcon.svg "$ICONSET/icon_${size}x${size}@2x.png" "$((size * 2))"
done
iconutil --convert icns "$ICONSET" --output Support/AppIcon.icns
echo "Built Support/AppIcon.icns"
