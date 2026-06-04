#!/usr/bin/env bash
set -euo pipefail

MODE="dry-run"

usage() {
  cat <<'EOF'
cleanup_claude_mem.sh

Safely clean rebuildable Claude/Claude-mem temporary files and logs.

Usage:
  bash scripts/cleanup_claude_mem.sh --dry-run
  bash scripts/cleanup_claude_mem.sh --apply

Safety:
  - Dry-run is the default.
  - This script only targets known temporary/cache/log paths.
  - It never deletes .env files, API keys, source code, project folders, or user notes.
  - Review dry-run output before using --apply.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --apply)
      MODE="apply"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

HOME_DIR="${HOME}"

# Conservative candidates only. Add project-specific paths after reviewing dry-run output.
CANDIDATES=(
  "${HOME_DIR}/.claude-mem/cache"
  "${HOME_DIR}/.claude-mem/logs"
  "${HOME_DIR}/.claude-mem/tmp"
  "${HOME_DIR}/.cache/claude-mem"
  "${HOME_DIR}/Library/Caches/claude-mem"
  "${HOME_DIR}/Library/Logs/claude-mem"
)

echo "Mode: ${MODE}"
echo "Scanning safe cleanup candidates..."
echo

SWITCH_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/claude_mem_switch.sh"
if [[ -x "${SWITCH_SCRIPT}" ]]; then
  bash "${SWITCH_SCRIPT}" scan
  echo
fi

found=0
for path in "${CANDIDATES[@]}"; do
  if [[ -e "${path}" ]]; then
    found=1
    if [[ "${MODE}" == "dry-run" ]]; then
      echo "[DRY-RUN] Would remove contents of: ${path}"
      du -sh "${path}" 2>/dev/null || true
    else
      echo "[APPLY] Removing contents of: ${path}"
      find "${path}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    fi
  fi
done

if [[ "${found}" -eq 0 ]]; then
  echo "No known claude-mem cache/log folders found."
fi

echo
if [[ "${MODE}" == "dry-run" ]]; then
  echo "Dry-run complete. Re-run with --apply only if the listed paths are safe."
else
  echo "Cleanup complete."
fi
