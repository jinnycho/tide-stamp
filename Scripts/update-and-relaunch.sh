#!/bin/zsh
set -euo pipefail

OLD_PID="${1:?missing old process id}"
APP_PATH="${2:-/Applications/TideStamp.app}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLER="${SWIFT_BUNDLER:-$HOME/.mint/bin/swift-bundler}"

notify() {
  /usr/bin/osascript -e "display notification \"$1\" with title \"TideStamp\""
}

notify "Updating from origin/main..."

# Wait until the running app exits before replacing the bundle in /Applications.
while /bin/kill -0 "$OLD_PID" 2>/dev/null; do
  /bin/sleep 0.2
done

cd "$REPO_DIR"

# Keep the updater predictable: local edits or divergent history should stop the
# update instead of silently overwriting work or creating a merge commit.
/usr/bin/git diff --quiet
/usr/bin/git diff --cached --quiet
/usr/bin/git fetch origin main
/usr/bin/git checkout main
/usr/bin/git pull --ff-only origin main

"$BUNDLER" bundle TideStamp --bundler darwinApp -c release

/bin/rm -rf "$APP_PATH"
/bin/cp -R "$REPO_DIR/.build/bundler/apps/TideStamp/TideStamp.app" "$APP_PATH"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_PATH"
/usr/bin/open "$APP_PATH"

notify "Update complete."
