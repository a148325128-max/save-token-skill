#!/usr/bin/env bash
set -euo pipefail

SETTINGS_PATH="${CLAUDE_SETTINGS_PATH:-${HOME}/.claude/settings.json}"
PLUGIN_ID="${CLAUDE_MEM_PLUGIN_ID:-claude-mem@thedotmack}"
MEM_DIR="${CLAUDE_MEM_DIR:-${HOME}/.claude-mem}"

usage() {
  cat <<'EOF'
claude_mem_switch.sh

Check, disable, or re-enable the claude-mem plugin flag in Claude settings.

Usage:
  bash scripts/claude_mem_switch.sh scan
  bash scripts/claude_mem_switch.sh status
  bash scripts/claude_mem_switch.sh disable
  bash scripts/claude_mem_switch.sh enable

Safety:
  - Creates a timestamped backup before modifying settings.
  - Only changes enabledPlugins["claude-mem@thedotmack"].
  - Does not delete memory databases, logs, API keys, .env files, or project files.
  - Restart Claude / Claude Code after changing plugin state.

Environment overrides:
  CLAUDE_SETTINGS_PATH=/path/to/settings.json
  CLAUDE_MEM_PLUGIN_ID=claude-mem@thedotmack
  CLAUDE_MEM_DIR=/path/to/.claude-mem
EOF
}

require_node() {
  if ! command -v node >/dev/null 2>&1; then
    echo "Error: node is required to safely edit JSON." >&2
    exit 1
  fi
}

require_settings() {
  if [[ ! -f "${SETTINGS_PATH}" ]]; then
    echo "Error: settings file not found: ${SETTINGS_PATH}" >&2
    exit 1
  fi
}

status() {
  require_node
  require_settings
  node - "${SETTINGS_PATH}" "${PLUGIN_ID}" <<'NODE'
const fs = require('fs');
const [settingsPath, pluginId] = process.argv.slice(2);
const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
const enabledPlugins = settings.enabledPlugins || {};
const value = enabledPlugins[pluginId];
if (value === true) {
  console.log(`claude-mem status: enabled (${pluginId}: true)`);
} else if (value === false) {
  console.log(`claude-mem status: disabled (${pluginId}: false)`);
} else {
  console.log(`claude-mem status: not configured (${pluginId} missing)`);
}
NODE
  echo
  scan_mem
}

scan_mem() {
  require_node
  node - "${MEM_DIR}" <<'NODE'
const fs = require('fs');
const path = require('path');

const memDir = process.argv[2];

function exists(p) {
  try {
    fs.accessSync(p);
    return true;
  } catch {
    return false;
  }
}

function sizeOf(p) {
  if (!exists(p)) return 0;
  const st = fs.lstatSync(p);
  if (st.isSymbolicLink()) return 0;
  if (st.isFile()) return st.size;
  if (!st.isDirectory()) return 0;
  let total = 0;
  for (const name of fs.readdirSync(p)) {
    total += sizeOf(path.join(p, name));
  }
  return total;
}

function countFiles(p) {
  if (!exists(p)) return 0;
  const st = fs.lstatSync(p);
  if (st.isSymbolicLink()) return 0;
  if (st.isFile()) return 1;
  if (!st.isDirectory()) return 0;
  let total = 0;
  for (const name of fs.readdirSync(p)) {
    total += countFiles(path.join(p, name));
  }
  return total;
}

function human(bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  let n = bytes;
  let i = 0;
  while (n >= 1024 && i < units.length - 1) {
    n /= 1024;
    i++;
  }
  return `${n.toFixed(n >= 10 || i === 0 ? 0 : 1)} ${units[i]}`;
}

function bar(bytes, total) {
  const width = 20;
  const ratio = total > 0 ? bytes / total : 0;
  const filled = Math.max(0, Math.min(width, Math.round(ratio * width)));
  return `${'#'.repeat(filled)}${'-'.repeat(width - filled)}`;
}

const items = [
  ['database', path.join(memDir, 'claude-mem.db')],
  ['database-wal', path.join(memDir, 'claude-mem.db-wal')],
  ['chroma', path.join(memDir, 'chroma')],
  ['logs', path.join(memDir, 'logs')],
  ['backups', path.join(memDir, 'backups')],
  ['corpora', path.join(memDir, 'corpora')],
  ['observer-sessions', path.join(memDir, 'observer-sessions')],
  ['settings/config', path.join(memDir, 'settings.json')],
];

console.log(`claude-mem scan: ${memDir}`);
if (!exists(memDir)) {
  console.log('No claude-mem directory found.');
  process.exit(0);
}

const rows = items.map(([label, p]) => ({
  label,
  p,
  bytes: sizeOf(p),
  files: countFiles(p),
})).filter(row => row.bytes > 0 || exists(row.p));

const total = sizeOf(memDir);
console.log(`total: ${human(total)} (${countFiles(memDir)} files)`);
console.log('');
for (const row of rows) {
  const pct = total > 0 ? `${((row.bytes / total) * 100).toFixed(1)}%` : '0.0%';
  console.log(`${row.label.padEnd(18)} ${human(row.bytes).padStart(8)} ${pct.padStart(7)} ${bar(row.bytes, total)} ${row.files} files`);
}

const warnings = [];
const logs = rows.find(r => r.label === 'logs');
const backups = rows.find(r => r.label === 'backups');
const chroma = rows.find(r => r.label === 'chroma');
if (logs && logs.bytes > 20 * 1024 * 1024) warnings.push(`logs are large: ${human(logs.bytes)}`);
if (backups && backups.bytes > 100 * 1024 * 1024) warnings.push(`backups are large: ${human(backups.bytes)}`);
if (chroma && chroma.bytes > 500 * 1024 * 1024) warnings.push(`chroma is large: ${human(chroma.bytes)}`);

if (warnings.length) {
  console.log('');
  console.log('warnings:');
  for (const warning of warnings) console.log(`- ${warning}`);
}
NODE
}

set_flag() {
  local desired="$1"
  require_node
  require_settings

  local ts backup
  ts="$(date +%Y%m%d-%H%M%S)"
  backup="${SETTINGS_PATH}.bak-save-token-skill-${ts}"
  cp "${SETTINGS_PATH}" "${backup}"

  node - "${SETTINGS_PATH}" "${PLUGIN_ID}" "${desired}" <<'NODE'
const fs = require('fs');
const [settingsPath, pluginId, desiredRaw] = process.argv.slice(2);
const desired = desiredRaw === 'true';
const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
settings.enabledPlugins = settings.enabledPlugins || {};
settings.enabledPlugins[pluginId] = desired;
fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
console.log(`Set enabledPlugins["${pluginId}"] = ${desired}`);
NODE

  echo "Backup created: ${backup}"
  echo "Restart Claude / Claude Code for the change to take effect."
}

cmd="${1:-}"
case "${cmd}" in
  scan)
    scan_mem
    ;;
  status)
    status
    ;;
  disable)
    set_flag false
    ;;
  enable)
    set_flag true
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    echo "Unknown command: ${cmd}" >&2
    usage
    exit 1
    ;;
esac
