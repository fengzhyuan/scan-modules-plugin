# scan-modules

[中文](./README.zh-CN.md) | English

A Claude Code plugin that scans your codebase, extracts module structure, type declarations, and function signatures, then caches everything in local `.md` files for fast context loading across sessions.

## Why

Claude Code loses project context between sessions. This plugin creates a lightweight, git-tracked module cache that Claude can read in seconds instead of re-exploring your codebase every time.

**Before**: Claude spends 30-60s grepping around to understand project structure each session.
**After**: Claude reads INDEX.md (~80 lines) and knows every module, file, and function.

## Features

- **Full scan** — Discover all modules, extract types + function signatures, generate per-module docs
- **Incremental update** — Only re-scan modules with changed files (via git diff)
- **Status check** — See which modules are stale vs fresh
- **Git hook** — Auto-update module docs on every commit
- **Multi-language** — Swift, TypeScript/JavaScript, Python, Go, Rust

## Install

```bash
# From GitHub
/plugin install <github-url>

# Or test locally
claude --plugin-dir ./scan-modules-plugin
```

## Usage

```bash
# First time: full scan of your project
/scan-modules:scan-modules

# Check which modules need updating
/scan-modules:scan-modules status

# Update only changed modules
/scan-modules:scan-modules update

# Update a specific module
/scan-modules:scan-modules update vision

# Install git post-commit hook for auto-updates
/scan-modules:scan-modules install-hook
```

## What it generates

```
.claude/modules/
  INDEX.md              # Master index: all modules, dependency graph, usage
  auth.md               # Per-module: types, function signatures, dependencies
  blockchain.md
  vision.md
  ...
```

### INDEX.md (~80 lines)

Quick overview of all modules with file counts and descriptions. Read this at session start.

```markdown
<!-- SCAN_META: hash=abc1234 date=2026-03-02 -->
# Project Modules — MyApp
> Type: iOS/macOS | Language: Swift (SwiftUI)
> Modules: 36 | Files: 192

## Modules
| Module | Path | Files | Description |
|--------|------|-------|-------------|
| auth   | Services/Auth | 1 | JWT authentication and session management |
| vision | Services/Vision | 13 | On-device AI pipeline |
...
```

### Per-module files

Detailed function-level reference for each module.

```markdown
# Module: Vision
> Path: Services/Vision | Files: 13

## Files

### VisionAnalyzer.swift
**Type**: `class VisionAnalyzer` | **Purpose**: Image classification and face detection

| Visibility | Signature | Purpose |
|------------|-----------|---------|
| internal | `func analyze(_ image: UIImage) async -> ImageAnalysisResult` | Run Vision framework |

## Dependencies
- **Uses**: CoreML, Vision
- **Used by**: LazyNoteView, StorybookLayoutView
```

## How it works

1. **Detect project type** from marker files (Package.swift, package.json, Cargo.toml, etc.)
2. **Discover modules** by directory hierarchy
3. **Grep for signatures** — types, functions, published properties (never reads full files)
4. **Generate .md files** with consistent templates
5. **Track freshness** via git hash in SCAN_META comment

## Supported languages

| Language | Type patterns | Function patterns |
|----------|--------------|-------------------|
| Swift | `class/struct/protocol/actor/enum` | `func` |
| TypeScript | `class/interface/type/enum` | `function`, `export const` |
| Python | `class` | `def`, `async def` |
| Go | `type ... struct/interface` | `func` |
| Rust | `struct/enum/trait` | `fn`, `pub fn` |

## Git hook

`/scan-modules:scan-modules install-hook` installs a post-commit hook that:
- Runs in background (doesn't slow down commits)
- Only regenerates modules with changed files
- Updates INDEX.md hash automatically

## Tips

- Add `.claude/modules/` to `.gitignore` — these are local cache files
- Read `INDEX.md` at session start for project overview
- Read per-module `.md` on demand when working in that area
- Run `status` periodically to check freshness

## License

MIT
