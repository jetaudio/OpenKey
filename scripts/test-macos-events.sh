#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/openkey-mac-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
xcrun clang++ -std=c++14 -g -fobjc-arc -fobjc-weak -fsanitize=address,undefined \
  -I Sources/OpenKey/engine -I Sources/OpenKey/macOS/ModernKey \
  Sources/OpenKey/engine/*.cpp tests/mac_event_tests.mm \
  -framework Cocoa -framework Carbon -o "$test_dir/event-tests"
"$test_dir/event-tests"
xcrun clang -g -fobjc-arc -fobjc-weak -fsanitize=address,undefined \
  -I Sources/OpenKey/macOS/ModernKey tests/mac_tap_tests.m \
  -framework Cocoa -o "$test_dir/tap-tests"
"$test_dir/tap-tests"
