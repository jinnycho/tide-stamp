#!/bin/zsh

set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

app_pid=""

snapshot() {
    {
        stat -f "%m %N" Package.swift 2>/dev/null
        find Sources -type f -name "*.swift" -print0 2>/dev/null \
            | xargs -0 stat -f "%m %N" 2>/dev/null
    } | sort
}

stop_app() {
    if [[ -n "$app_pid" ]] && kill -0 "$app_pid" 2>/dev/null; then
        echo "Stopping TideStamp..."
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
    fi

    app_pid=""
}

start_app() {
    echo "Starting TideStamp..."
    swift run TideStamp &
    app_pid="$!"
}

cleanup() {
    stop_app
}

trap cleanup EXIT INT TERM

last_snapshot="$(snapshot)"
start_app

while true; do
    sleep 1

    current_snapshot="$(snapshot)"

    if [[ "$current_snapshot" != "$last_snapshot" ]]; then
        echo "Change detected. Restarting TideStamp..."
        last_snapshot="$current_snapshot"
        stop_app
        start_app
    fi
done
