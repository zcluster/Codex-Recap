#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
app="$script_dir/dist/Codex Recap.app"

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$script_dir/macos/Info.plist" "$app/Contents/Info.plist"

swiftc \
  -parse-as-library \
  -target arm64-apple-macos13.0 \
  -o "$app/Contents/MacOS/Codex Recap" \
  "$script_dir/macos/CodexRecentApp.swift" \
  -framework SwiftUI \
  -framework AppKit

echo "$app"
