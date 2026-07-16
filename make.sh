#!/usr/bin/env bash
set -euo pipefail

DEST="${1:-/opt/homebrew/bin}"

swift build --configuration release
cp -f .build/release/swifty-jira "$DEST/"

# Re-sign after copying: macOS invalidates the code signature when the binary
# is copied, which causes the OS to SIGKILL it (exit 137) on launch.
codesign --force --sign - "$DEST/swifty-jira"

echo "Installed swifty-jira to $DEST"
