#!/bin/zsh
set -e
cd "$(dirname "$0")/.."
swift build -c release
APP="build/CornerNotes.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/CornerNotes "$APP/Contents/MacOS/CornerNotes"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
echo "Built $APP"
