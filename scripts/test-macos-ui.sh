#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -ne 2 ]; then
  echo 'Usage: bash scripts/test-macos-ui.sh /path/to/built/OpenKey.app /path/to/preferences.png' >&2
  exit 2
fi
app_path="$1"
render_path="$2"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/openkey-ui-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
flags=(-g -I Sources/OpenKey/engine -I Sources/OpenKey/macOS/ModernKey)
for source in Sources/OpenKey/engine/*.cpp Sources/OpenKey/macOS/ModernKey/*.mm; do
  xcrun clang++ -std=c++14 -fobjc-arc -fobjc-weak "${flags[@]}" -c "$source" -o "$test_dir/$(basename "$source").o"
done
for source in Sources/OpenKey/macOS/ModernKey/*.m tests/mac_ui_qa.m; do
  if [ "$(basename "$source")" = main.m ]; then continue; fi
  xcrun clang -fobjc-arc -fobjc-weak "${flags[@]}" -c "$source" -o "$test_dir/$(basename "$source").o"
done
xcrun clang++ "$test_dir/"*.o -framework Cocoa -framework Carbon \
  -framework ServiceManagement -framework IOKit -o "$test_dir/OpenKeyUIReview"
"$test_dir/OpenKeyUIReview" "$app_path" "$render_path"
