#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
release_dir="$script_dir/release"
archive="$release_dir/Codex-Recap-macOS-arm64.zip"

"$script_dir/build_app.sh"
mkdir -p "$release_dir"
rm -f "$archive" "$release_dir/SHA256SUMS.txt"
ditto -c -k --norsrc --noextattr --noqtn --noacl --keepParent \
  "$script_dir/dist/Codex Recap.app" \
  "$archive"

cd "$release_dir"
shasum -a 256 "${archive:t}" > SHA256SUMS.txt
echo "$archive"
