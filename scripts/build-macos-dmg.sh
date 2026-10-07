#!/bin/bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

if ! xcodebuild -version; then
  echo 'Full Xcode is required. Set DEVELOPER_DIR to Xcode.app/Contents/Developer.' >&2
  exit 1
fi

build_dir="$(mktemp -d "${TMPDIR:-/tmp}/openkey-build.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
mkdir -p dist

xcodebuild \
  -project Sources/OpenKey/macOS/OpenKey.xcodeproj \
  -scheme OpenKey \
  -configuration Release \
  -derivedDataPath "$build_dir/DerivedData" \
  -destination 'generic/platform=macOS' \
  'ARCHS=arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  MACOSX_DEPLOYMENT_TARGET=12.0 \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  DEVELOPMENT_TEAM= \
  OTHER_LDFLAGS=-lc++ \
  build

app_path="$build_dir/DerivedData/Build/Products/Release/OpenKey.app"
test -d "$app_path/Contents/Resources/Base.lproj/Main.storyboardc"
test -f "$app_path/Contents/Frameworks/librime.1.dylib"
test -f "$app_path/Contents/Resources/Rime/build/pinyin_simp.table.bin"
for arch in arm64 x86_64; do
  lipo "$app_path/Contents/MacOS/OpenKey" -verify_arch "$arch"
done
codesign --force --sign - "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"
plutil -lint "$app_path/Contents/Info.plist"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
commit="$(git rev-parse --short=12 HEAD)"
artifact="OpenKey-${version}-${commit}-universal"
stage_dir="$build_dir/stage"
mkdir -p "$stage_dir"
ditto "$app_path" "$stage_dir/OpenKey.app"
ln -s /Applications "$stage_dir/Applications"
cp LICENSE "$stage_dir/LICENSE.txt"

{
  echo "Version: $version"
  echo "Source commit: $(git rev-parse HEAD)"
  echo 'Architectures: arm64, x86_64'
  echo 'Signing: ad hoc (not notarized)'
  xcodebuild -version
} > "dist/${artifact}-BUILD-INFO.txt"

hdiutil create -volname "OpenKey $version" -srcfolder "$stage_dir" \
  -format UDZO -ov "dist/${artifact}.dmg"
hdiutil verify "dist/${artifact}.dmg"
(cd dist && shasum -a 256 "${artifact}.dmg" > "${artifact}.dmg.sha256")
echo "Created: $repo_dir/dist/${artifact}.dmg"
