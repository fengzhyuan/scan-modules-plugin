---
name: auto-context
description: Automatically load project module cache at conversation start. Use this at the beginning of every conversation to understand the project structure, or when the user asks about project architecture, modules, or file organization.
---

# Auto-load Module Cache

At the **start of every conversation**, perform these steps:

## Step 1: Check if module cache exists

Look for `.claude/modules/INDEX.md` in the project root.

- If it **does not exist**, skip silently. Do not prompt the user unless they ask about project structure.
- If it **exists**, proceed to Step 2.

## Step 2: Read INDEX.md

Read `.claude/modules/INDEX.md` to load the project module overview. This gives you:
- All modules with file counts and descriptions
- Dependency graph between modules
- Total project size

Store this context for the session. When the user asks about a specific module, read the corresponding `.claude/modules/{module-name}.md` for function-level detail.

## Step 3: Check freshness

Extract the git hash from the `SCAN_META` comment at the top of INDEX.md:
```
<!-- SCAN_META: hash={hash} date={date} -->
```

Compare it with the current HEAD:
```bash
git rev-parse --short HEAD
```

- If hashes **match**: cache is fresh, proceed normally.
- If hashes **differ**: inform the user briefly:
  > "Module cache is stale (last scan: {date}). Run `/scan-modules:scan-modules update` to refresh."

Do NOT auto-run the update. Just inform once and move on.

## Step 4: Use context naturally

When working on tasks:
- Reference module names and their dependencies from INDEX.md
- Read per-module `.md` files on demand when you need function signatures
- If the user asks "what does X module do?" — read `.claude/modules/X.md` first before grepping source
