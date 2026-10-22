#!/usr/bin/env bash
# Command-line helper for the Unity project.
#
# Usage:
#   ./unity.sh open                      Open the project in the Unity Editor
#   ./unity.sh build [target] [--dev]    Build a player (mac, windows, linux, webgl; default mac)
#   ./unity.sh test [editmode|playmode]  Run tests (default editmode)
#
# Set UNITY_PATH to use a different editor than the one in ProjectVersion.txt.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$ROOT/MyUnityGameGithub"
LOG_DIR="$ROOT/Logs"
VERSION="$(sed -n 's/^m_EditorVersion: //p' "$PROJECT/ProjectSettings/ProjectVersion.txt")"

if [[ -z "${UNITY_PATH:-}" ]]; then
  case "$(uname)" in
    Darwin) UNITY_PATH="/Applications/Unity/Hub/Editor/$VERSION/Unity.app/Contents/MacOS/Unity" ;;
    Linux)  UNITY_PATH="$HOME/Unity/Hub/Editor/$VERSION/Editor/Unity" ;;
    *)      UNITY_PATH="/c/Program Files/Unity/Hub/Editor/$VERSION/Editor/Unity.exe" ;;
  esac
fi

if [[ ! -x "$UNITY_PATH" ]]; then
  echo "Unity $VERSION not found at: $UNITY_PATH" >&2
  echo "Install it with Unity Hub or set UNITY_PATH." >&2
  exit 1
fi

mkdir -p "$LOG_DIR"
cmd="${1:-}"
shift || true

case "$cmd" in
  open)
    "$UNITY_PATH" -projectPath "$PROJECT" "$@" &
    ;;
  build)
    target="${1:-mac}"
    extra=()
    [[ "${2:-}" == "--dev" || "${1:-}" == "--dev" ]] && extra+=(-development)
    [[ "$target" == "--dev" ]] && target=mac
    log="$LOG_DIR/build-$target.log"
    echo "Building $target with Unity $VERSION (log: $log)..."
    "$UNITY_PATH" -batchmode -nographics -quit -projectPath "$PROJECT" \
      -executeMethod CommandLineBuild.Build \
      -buildTarget "$target" -buildPath "$ROOT/Builds/$target" \
      "${extra[@]+"${extra[@]}"}" -logFile "$log" \
      && echo "Build done: $ROOT/Builds/$target" \
      || { echo "Build failed. Last errors:" >&2; grep -E "error|Error" "$log" | tail -20 >&2; exit 1; }
    ;;
  test)
    platform="${1:-editmode}"
    results="$LOG_DIR/test-results-$platform.xml"
    log="$LOG_DIR/test-$platform.log"
    echo "Running $platform tests (results: $results)..."
    "$UNITY_PATH" -batchmode -nographics -projectPath "$PROJECT" \
      -runTests -testPlatform "$platform" -testResults "$results" -logFile "$log" \
      && echo "Tests passed." \
      || { echo "Tests failed or could not run. See $results and $log" >&2; exit 1; }
    ;;
  *)
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
