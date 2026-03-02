---
name: auto-context
description: "IMPORTANT: Use this proactively at the START of every conversation to load the project module cache. Also use when exploring/searching code, investigating architecture, or when the user asks about project structure. This skill MUST be invoked before any codebase exploration task."
---

# Auto-load Module Cache

**IMPORTANT**: This skill should be invoked proactively at the start of every conversation when `.claude/modules/INDEX.md` exists. Do NOT wait for the user to ask.

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

## Step 5: Code search workflow — MODULE CACHE FIRST

**When searching or exploring the codebase**, ALWAYS follow this order:

1. **Read INDEX.md first** — identify which modules are relevant to the search
2. **Read per-module `.md` files** — get type declarations, function signatures, and dependencies for the relevant modules
3. **Only then grep/glob source files** — when module cache doesn't have enough detail (e.g., function body logic, variable values, implementation specifics)

This saves significant time vs. blind grep searches across the entire codebase.

### Examples

**User asks: "How does avatar loading work?"**
```
1. Read INDEX.md → find relevant modules: domain (UserService), photo (TextureCacheService), photo-views (avatar components)
2. Read .claude/modules/domain.md → find updateAvatar(), updateProfile() signatures
3. Read .claude/modules/photo.md → find loadImage() signature
4. Only grep source if you need implementation details
```

**User asks: "Find all notification handlers"**
```
1. Read INDEX.md → check which modules likely use notifications
2. Read relevant module .md files → find notification-related functions
3. Grep for specific patterns only if module cache is insufficient
```

### When dispatching Explore/Task agents

When using the Task tool with `subagent_type: Explore` or other agents for code investigation, include this in the agent prompt:

> "Check `.claude/modules/INDEX.md` first to identify relevant modules, then read the corresponding `.claude/modules/{module}.md` files for type and function details before grepping source code."
