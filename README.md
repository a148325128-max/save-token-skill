# Save Token Skill

A Claude Skill for diagnosing abnormal token usage in Claude + DeepSeek / Claude Code workflows.

It is designed for fuzzy triggering. Users should not have to say the exact skill name. Phrases like `token 消耗很高`, `额度掉得很快`, `缓存命中率低`, `Claude Code 很费 token`, or `claude-mem 报错` should all route to this skill.

It supports two modes:

- **Manual diagnosis**: ask Claude to use the skill when token usage spikes.
- **Maintenance cleanup**: run a safe dry-run cleanup script for rebuildable cache/log folders.
- **Mem switch**: check, disable, or re-enable claude-mem if cleanup does not fix repeated errors.
- **Mem scan**: show database/log/cache sizes in KB/MB/GB before taking action.

## What It Does

The skill checks:

1. Cache hit/miss changes
2. Repeated project/context loading
3. Plugin or memory error loops
4. Context hygiene problems

It then returns:

- Most likely cause
- Evidence
- Fix now
- Prevent next time
- Missing data to verify

## Files

```text
save-token-skill/
├── SKILL.md
├── README.md
└── scripts/
    ├── cleanup_claude_mem.sh
    └── claude_mem_switch.sh
```

## Manual Prompt

```text
Use the Save Token Skill.

Current workflow:
Claude Code + DeepSeek.

Problem:
Token usage suddenly increased and cache hit rate dropped.

Please diagnose the most likely cause and give me three safe fixes.
```

## Cleanup Script

Scan first:

```bash
bash scripts/claude_mem_switch.sh scan
```

Always run dry-run first:

```bash
bash scripts/cleanup_claude_mem.sh --dry-run
```

Apply only after reviewing the paths:

```bash
bash scripts/cleanup_claude_mem.sh --apply
```

## Scheduling

This skill is not itself a scheduler. If you want periodic cleanup, schedule the script with cron or launchd after reviewing dry-run output.

Example weekly cron entry:

```cron
0 9 * * 1 /bin/bash /absolute/path/to/save-token-skill/scripts/cleanup_claude_mem.sh --apply
```

Prefer weekly cleanup over daily cleanup unless you have a confirmed recurring cache/log issue.

## Mem Switch

If cleanup does not help and claude-mem keeps erroring, check the plugin flag:

```bash
bash scripts/claude_mem_switch.sh status
```

`status` also prints a visual size scan for the mem directory.

Temporarily disable it:

```bash
bash scripts/claude_mem_switch.sh disable
```

Re-enable it later:

```bash
bash scripts/claude_mem_switch.sh enable
```

If `status` shows disabled and Claude + DeepSeek works better with mem off, keep it disabled. Re-enable only when you explicitly need memory again and are ready to test whether the issue returns.

The switch script:

- Creates a timestamped backup before editing settings.
- Only changes `enabledPlugins["claude-mem@thedotmack"]`.
- Does not delete memory data, logs, API keys, `.env` files, or project files.

Restart Claude / Claude Code after changing plugin state.

## Safety

The script is conservative by default:

- It uses `--dry-run` unless `--apply` is provided.
- It only targets known cache/log/temp paths.
- It does not delete source code, project folders, `.env` files, API keys, or user notes.
- The mem switch only changes the plugin enabled flag and creates a backup first.
- Do not automatically re-enable mem after stability improves with mem disabled.
