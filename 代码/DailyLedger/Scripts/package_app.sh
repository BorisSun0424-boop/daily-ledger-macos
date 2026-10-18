#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="$PROJECT_DIR/dist/日常记账.app"
CONTENTS_DIR="$APP_DIR/Contents"

cd "$PROJECT_DIR"
swift build -c release

if [[ -d "$APP_DIR" ]]; then
  rm -rf "$APP_DIR"
fi

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$PROJECT_DIR/.build/release/DailyLedger" "$CONTENTS_DIR/MacOS/DailyLedger"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod 755 "$CONTENTS_DIR/MacOS/DailyLedger"
codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
