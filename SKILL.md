# Save Token Skill

Use this skill automatically when the user says or implies that token usage is too high, credits are dropping quickly, cache hit rate is low, Claude + DeepSeek is consuming too much, Claude Code is repeatedly reading context, or claude-mem/memory is causing errors.

Fuzzy trigger phrases include:

- `token 消耗很高`
- `token 用得太快`
- `token 爆了`
- `额度掉得很快`
- `DeepSeek 消耗很快`
- `缓存命中率低`
- `未命中缓存很多`
- `Claude 一直重复读项目`
- `Claude Code 很费 token`
- `claude-mem 报错`
- `mem 太大`
- `memory 太多`
- `帮我省 token`
- `帮我查 token`
- `token usage is high`
- `cache hit rate is low`
- `prompt cache miss is high`

Do not require the user to explicitly say `Use the Save Token Skill`. If the user mentions token overuse, cache misses, quota/credit dropping quickly, or claude-mem bloat/errors, invoke this skill.

This skill supports two modes:

1. **Manual diagnosis mode**: run immediately when the user asks to diagnose token waste.
2. **Maintenance mode**: guide the user to run safe cleanup scripts periodically for known rebuildable caches and logs.
3. **Mem switch mode**: check, disable, or re-enable claude-mem if cleanup does not solve repeated errors.
4. **Mem scan mode**: show claude-mem database/log/cache sizes in KB/MB/GB before cleanup or switching.

## Goal

Diagnose where tokens are being wasted and produce a short action plan that reduces repeated context loading, cache misses, and error-loop retries.

Do not blame the model first. First check whether the workflow is repeatedly rebuilding context, reading the same files, or retrying failed tools.

Do not delete user projects, API keys, account configs, source code, or persistent knowledge bases. Cleanup must be limited to temporary files, logs, stale caches, and explicitly user-approved paths.

## Inputs

Ask the user for any available data:

- Recent token chart or usage screenshot
- `prompt_cache_hit_tokens`
- `prompt_cache_miss_tokens`
- Output tokens
- Error logs from Claude Code, plugin, MCP, or memory tools
- Project type and task being run
- Whether the same project was run before with normal usage

If exact logs are missing, continue with a best-effort checklist and clearly mark unknowns.

## Diagnosis Checklist

### 1. Cache Hit Check

Look for:

- Cache hit tokens suddenly dropping
- Cache miss tokens suddenly rising
- Same project/task producing much more uncached input than before

Interpretation:

- High miss tokens usually means the request prefix is not being reused, or the tool is rebuilding context differently.
- Do not claim this is definitely a model issue unless logs prove it.

### 2. Repeated Context Loading Check

Look for signs that Claude keeps rereading:

- Full project directories
- Large README/docs
- Generated files
- Build output
- Lock files
- Logs
- Previous chat summaries

If repeated loading appears likely, suggest limiting context to:

- Current task
- Relevant files only
- A stable project summary
- A short task-specific file list

### 3. Error Loop Check

Look for:

- The same tool call failing repeatedly
- Memory/plugin errors
- MCP connection failures
- File read/write retries
- Search commands repeated without progress

If an error loop appears likely, suggest:

- Stop the current run
- Clear or disable the failing memory/plugin temporarily
- Re-run with a smaller task
- Pin the known-good version if a recent update caused the issue

### 4. Context Hygiene Check

Look for inputs that create unnecessary token use:

- Asking broad questions like "read the whole project"
- Mixing multiple tasks in one request
- Letting Claude inspect unrelated folders
- Repeating long background explanations every time
- Including API docs, logs, and source code together without priority

Suggest rewriting the task as:

1. Project context
2. Current task
3. Relevant files
4. Output format
5. Stop conditions

## Output Format

Return the diagnosis in this structure:

```markdown
## Token Diagnosis

### Most likely cause
One clear sentence.

### Evidence
- Evidence 1
- Evidence 2
- Evidence 3

### Fix now
1. Step one
2. Step two
3. Step three

### Prevent next time
- Rule 1
- Rule 2
- Rule 3

### What I still need to verify
- Missing data or log
```

## Manual Usage

When the user says something like:

```text
Use the Save Token Skill.
Claude + DeepSeek token usage is abnormal.
```

Run manual diagnosis first. Ask for token chart or logs if useful, then return:

- Most likely cause
- Evidence
- Fix now
- Prevent next time
- What still needs verification

## Maintenance Usage

When the user asks for periodic cleanup or prevention, explain that the skill itself is not a background scheduler. It can provide scripts and instructions that can be run manually or scheduled with cron/launchd.

Available helper script:

```bash
scripts/cleanup_claude_mem.sh
```

Available mem switch script:

```bash
scripts/claude_mem_switch.sh
```

First scan memory size:

```bash
bash scripts/claude_mem_switch.sh scan
```

The scan shows total size, database size, chroma/vector store size, logs, backups, corpora, and file counts with a visual bar.

Recommended safe flow:

1. Run dry-run first:

```bash
bash scripts/cleanup_claude_mem.sh --dry-run
```

2. Review what would be deleted.
3. Run cleanup only after the user approves:

```bash
bash scripts/cleanup_claude_mem.sh --apply
```

4. Compare token/cache data before and after.

## Mem Switch Usage

Use this only when:

- claude-mem logs or data are too large
- cleanup has already been tried
- claude-mem continues to error-loop
- the user explicitly wants to temporarily disable memory
- claude-mem is already disabled and the workflow becomes more stable; in that case, keep it disabled unless the user explicitly needs memory again

Safe flow:

1. Check status:

```bash
bash scripts/claude_mem_switch.sh status
```

`status` also runs the visual mem scan so the user can see how large the mem files are before deciding what to do.

2. Disable with backup:

```bash
bash scripts/claude_mem_switch.sh disable
```

3. Restart Claude / Claude Code so plugin settings reload.

4. Re-enable later if needed:

```bash
bash scripts/claude_mem_switch.sh enable
```

Never silently disable claude-mem. Explain that disabling memory may reduce recall of prior project context.

If status is already disabled and the user reports the workflow is better, do not recommend enabling it again. Record this as a positive stability signal and continue with memory-off operation.

## Safe Recommendations

Prefer these recommendations:

- Split large tasks into smaller steps
- Keep project context stable
- Ask Claude to inspect only relevant files
- Clear broken memory/plugin state
- Pin or downgrade a tool only when an update is known to cause errors
- Track cache hit and miss tokens before and after changes
- Show mem size scan before cleanup or disabling
- Run cleanup scripts in dry-run mode before applying changes
- Schedule cleanup only for explicitly safe paths
- Temporarily disable claude-mem only after backup and user confirmation
- Re-enable claude-mem only when the user explicitly needs memory again and accepts the risk of renewed errors

Avoid these recommendations unless the user explicitly asks:

- Sharing API keys
- Showing account balance
- Downloading unofficial tools
- Bypassing limits
- Claiming a model or provider is intentionally wasting tokens
- Deleting unknown folders
- Deleting API keys, config files, `.env` files, project source, or user-created notes
- Permanently disabling memory without telling the user how to restore it
- Re-enabling claude-mem automatically after the user reports that disabling it improved stability

## Example Prompt

```text
Use the Save Token Skill.

Here is my token chart / usage data:
[paste data or screenshot summary]

Current workflow:
Claude Code + DeepSeek, running inside VS Code.

Problem:
Token usage suddenly increased, and cache hit rate dropped.

Please diagnose:
1. Most likely cause
2. What to check first
3. Three steps to reduce token waste
4. What data I should compare after fixing
```

## Example Periodic Cleanup Prompt

```text
Use the Save Token Skill maintenance mode.

Help me run a dry-run cleanup for Claude memory/cache logs.
Do not delete source code, API keys, .env files, or project documents.
Show me what would be cleaned before applying anything.
```

## Example Mem Scan Prompt

```text
Use the Save Token Skill mem scan mode.

Show me whether claude-mem is enabled, and show database/log/cache sizes in MB before doing any cleanup.
Do not delete anything.
```

## Example Mem Switch Prompt

```text
Use the Save Token Skill mem switch mode.

claude-mem is still erroring after cleanup.
Check whether it is enabled, then show me the safe disable command.
Do not delete memory data. Back up settings before changing anything.
```
