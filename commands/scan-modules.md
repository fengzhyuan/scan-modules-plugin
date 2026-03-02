# Scan Modules — Project Module Cache

Generate a structured module-level cache of the current project for efficient Claude context loading across sessions. Records every file, type declaration, and function signature organized by directory hierarchy.

## Input

$ARGUMENTS

## Parse Mode

Determine execution mode from arguments:

- Empty, "init", or "full" → **FULL_SCAN**
- "update" → **INCREMENTAL_UPDATE** (re-scan modules with changed files)
- "install-hook" → **INSTALL_HOOK** (add git post-commit hook for auto-update)
- "update `<name>`" → **MODULE_UPDATE** (re-scan one specific module)
- "status" → **STATUS_CHECK**

---

## FULL_SCAN Mode

### Step 1: Detect Project

Check repository root for marker files:

| Marker | Project Type | Language |
|--------|-------------|----------|
| Package.swift, *.xcodeproj, *.xcworkspace | iOS/macOS | Swift |
| package.json + tsconfig.json | TypeScript | TypeScript |
| package.json (no tsconfig) | JavaScript | JavaScript |
| Cargo.toml | Rust | Rust |
| go.mod | Go | Go |
| pyproject.toml, setup.py, requirements.txt | Python | Python |
| build.gradle, pom.xml | JVM | Java/Kotlin |

Record: project name (from directory), type, primary language. If multiple languages detected, note all of them.

### Step 2: Discover Modules

Modules are defined by **directory hierarchy**. Use Glob to scan source directories.

**iOS/Swift**: Start from the main app target directory (e.g., `<ProjectName>/`).
- Each top-level subdirectory is a **module category** (Services, Views, ViewModels, Models, Utils, Config)
- Each sub-directory within a category is a **module** (e.g., `Services/Vision`, `Views/Components/Photo`)
- If a sub-directory has further sub-directories, each is a **sub-module**
- Files directly in a category root belong to that category's module

**TypeScript/JavaScript**: Start from `src/`.
- Each subdirectory under `src/` is a module
- Nested directories with 2+ files form sub-modules

**Python**: Start from the main package directory.
- Each directory containing `__init__.py` is a module

**Go**: Each directory containing `.go` files is a module (maps to Go packages).

**Rust**: Each directory under `src/` with `mod.rs`, or modules declared in `lib.rs`/`main.rs`.

**General rules**:
- Skip: node_modules, .build, DerivedData, Pods, vendor, dist, build, __pycache__, .git, .claude, Frameworks, Tests (unless specifically requested)
- A module must have at least 1 source file
- Module naming: kebab-case from path (e.g., `Services/Vision` → `vision`, `Views/Components/Photo` → `photo-views`)

### Step 3: Scan Each Module

For each module, extract ALL of the following:

#### 3a. File inventory
List every source file in the module with a one-line purpose.

#### 3b. Type declarations
Extract all types (classes, structs, protocols, enums, actors, interfaces, traits) with:
- Name and kind
- Inheritance/conformance
- One-line purpose

#### 3c. Function signatures
Extract EVERY public/internal function with:
- Full signature (name, parameters with types, return type)
- Brief purpose (3-10 words; infer from name if doc comment absent)
- Mark `async`, `throws`, `static`, `@MainActor` etc.

**Language-specific Grep patterns:**

**Swift:**
```
Types:     (class|struct|protocol|actor|enum)\s+\w+
Functions: (static\s+|class\s+)?func\s+\w+
Properties: (var|let)\s+\w+\s*:\s*\S+  (important published/public ones only)
```

**TypeScript/JavaScript:**
```
Types:     (export\s+)?(class|interface|type|enum)\s+\w+
Functions: (export\s+)?(async\s+)?function\s+\w+|export\s+const\s+\w+\s*=
```

**Python:**
```
Types:     class\s+\w+
Functions: (async\s+)?def\s+\w+
```

**Go:**
```
Types:     type\s+\w+\s+(struct|interface)
Functions: func\s+(\(\w+\s+\*?\w+\)\s+)?\w+
```

**Rust:**
```
Types:     (pub\s+)?(struct|enum|trait)\s+\w+
Functions: (pub\s+)?(async\s+)?fn\s+\w+
```

**Strategy**: Use Grep with these patterns to find signatures efficiently. Only Read a file when you need to understand a function's purpose from its body. Scan multiple modules in parallel using parallel tool calls.

### Step 4: Analyze Dependencies

For each module:
1. Grep for import/use/include statements within the module files
2. Map imports to other discovered modules
3. Record bidirectional: "Uses: [modules]" and "Used by: [modules]"

For Swift: look for type references across files. A module "uses" another if its files reference types defined in that module.

### Step 5: Generate Output

Create `.claude/modules/` directory. Generate these files:

#### INDEX.md

```markdown
# Project Modules — {project_name}
> Type: {project_type} | Language: {language}
> Modules: {count} | Files: {total_files}
> Last scan: {YYYY-MM-DD} | Git: {short_hash of HEAD}

## Modules

| Module | Path | Files | Description |
|--------|------|-------|-------------|
| {name} | {relative_path} | {count} | {one-line description} |

## Dependency Graph
{module_a} → {module_b}, {module_c}
{module_d} → {module_b}

## Usage
- Session start: read this INDEX.md (~{N} lines)
- Need details: read `.claude/modules/{module-name}.md`
- Check freshness: `/scan-modules status`
- Update after changes: `/scan-modules update`
```

#### Per-module {name}.md

```markdown
# Module: {display_name}
> Path: {relative_path} | Files: {count}
> Last scan: {YYYY-MM-DD} | Git: {short_hash}

## Purpose
{2-3 sentence description of what this module does}

## Files

### {filename.ext}
**Type**: {primary type — class/struct/actor/etc.} | **Purpose**: {one-line}

| Visibility | Signature | Purpose |
|------------|-----------|---------|
| public | `func doSomething(param: Type) -> ReturnType` | Brief description |
| internal | `func helperMethod() async throws` | Brief description |

### {filename2.ext}
...

## Dependencies
- **Uses**: {list of other modules}
- **Used by**: {list of modules that depend on this}

## Notes
{Known issues, gotchas, or important patterns. Leave section empty if none.}
```

### Step 6: Post-scan

1. Print summary table: modules scanned, files processed, output path
2. Suggest adding `.claude/modules/` to `.gitignore` if not already there
3. If CLAUDE.md exists, suggest adding: `Module cache at .claude/modules/INDEX.md — read for project structure`
4. Record git HEAD hash in INDEX.md for freshness tracking

---

## INCREMENTAL_UPDATE Mode

### Step 1: Read INDEX.md
Read `.claude/modules/INDEX.md` to get last scan git hash.
If INDEX.md doesn't exist, fall back to FULL_SCAN.

### Step 2: Find Changed Files
Run: `git diff --name-only {last_scan_hash}..HEAD`
Also check: `git diff --name-only` (unstaged) and `git diff --name-only --cached` (staged)

### Step 3: Map Changes to Modules
Match each changed file path to its module directory. Build set of affected modules.

### Step 4: Re-scan Affected Modules Only
For each affected module, repeat FULL_SCAN Steps 3-4 for that module only.
For unaffected modules, keep existing .md files untouched.

### Step 5: Regenerate INDEX.md
- Update date and git hash in header
- Update table entries ONLY for affected modules
- Keep unaffected module entries as-is
- Recalculate dependency graph

### Step 6: Report
Print: which modules were updated, how many files changed, which modules were unchanged.

---

## MODULE_UPDATE Mode

Same as INCREMENTAL_UPDATE Step 4-5 but only for the named module.
If the name doesn't match any module in INDEX.md, print available modules and ask user to pick.

---

## STATUS_CHECK Mode

1. Read `.claude/modules/INDEX.md` — if missing, print "No module cache. Run `/scan-modules` to create." and stop
2. Extract last scan git hash from header
3. Run `git diff --name-only {hash}..HEAD` to find changed files
4. Map changed files to modules
5. Print status table:

```
Module Cache Status — {project_name}
Last scan: {date} ({hash})
Current HEAD: {current_hash}

| Module | Status | Changed Files |
|--------|--------|---------------|
| vision | Stale (3 files) | File1.swift, File2.swift, File3.swift |
| blockchain | Fresh | — |
| map | Fresh | — |

Stale modules: 1/9
Run `/scan-modules update` to refresh.
```

---

## Freshness Auto-Check

When this command generates or updates INDEX.md, include this comment at the top:

```markdown
<!-- SCAN_META: hash={git_short_hash} date={YYYY-MM-DD} -->
```

This allows automated freshness checking. If Claude reads INDEX.md at session start and the current git HEAD differs from the stored hash, Claude should proactively suggest: "Module cache is stale. Run `/scan-modules update` to refresh."

---

## INSTALL_HOOK Mode

Install a git `post-commit` hook that automatically updates affected module docs after each commit.

### Step 1: Check Prerequisites

1. Verify `.claude/modules/INDEX.md` exists — if not, print "Run `/scan-modules` first to create module cache." and stop.
2. Check if `.git/hooks/post-commit` already exists.
   - If it exists and already contains `scan-modules` / `update_modules`, print "Hook already installed." and stop.
   - If it exists with other content, **ask the user** whether to append or replace.

### Step 2: Detect Project & Build Module Map

Read INDEX.md to get the project type and module list. Build two lookup tables from the module entries:

1. **MODULE_MAP**: Maps directory path → module name (e.g., `Services/Auth` → `auth`)
2. **DISPLAY_NAMES**: Maps module name → display name (from INDEX.md table)
3. **PURPOSES**: Maps module name → description (from INDEX.md table)

### Step 3: Generate Hook Script

Write `.git/hooks/post-commit` with this structure:

```bash
#!/bin/bash
# Auto-generated by /scan-modules install-hook
# Updates .claude/modules/ for changed files after each commit

REPO_ROOT="$(git rev-parse --show-toplevel)"
MODULES_DIR="$REPO_ROOT/.claude/modules"
INDEX_FILE="$MODULES_DIR/INDEX.md"

[ -f "$INDEX_FILE" ] || exit 0

update_modules() {
    local NEW_HASH=$(git rev-parse --short HEAD)
    local NEW_DATE=$(date +%Y-%m-%d)
    local OLD_HASH=$(grep -o 'hash=[a-f0-9]*' "$INDEX_FILE" | head -1 | cut -d= -f2)

    # Find changed source files since last scan
    local CHANGED_FILES
    if [ -n "$OLD_HASH" ]; then
        CHANGED_FILES=$(git diff --name-only "$OLD_HASH"..HEAD -- '{source_glob}' 2>/dev/null)
    else
        CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD -- '{source_glob}' 2>/dev/null)
    fi
    [ -z "$CHANGED_FILES" ] && return 0

    # {MODULE_MAP as associative array}
    # {DISPLAY_NAMES as associative array}
    # {PURPOSES as associative array}

    # Map changed files to affected modules
    declare -A AFFECTED
    while IFS= read -r file; do
        local rel="${file#{source_prefix}/}"
        for dir_path in "${!MODULE_MAP[@]}"; do
            if [[ "$rel" == "$dir_path"/* ]]; then
                AFFECTED["${MODULE_MAP[$dir_path]}"]="$dir_path"
                break
            fi
        done
    done <<< "$CHANGED_FILES"
    [ ${#AFFECTED[@]} -eq 0 ] && return 0

    # Regenerate each affected module's .md file
    # (use language-appropriate grep patterns from FULL_SCAN Step 3)
    for mod_name in "${!AFFECTED[@]}"; do
        # ... extract types, functions, write .md file ...
    done

    # Update INDEX.md hash and date
    sed -i '' "s/<!-- SCAN_META: hash=[a-f0-9]* date=[0-9-]* -->/<!-- SCAN_META: hash=${NEW_HASH} date=${NEW_DATE} -->/" "$INDEX_FILE"
    sed -i '' "s/> Last scan: [0-9-]* | Git: [a-f0-9]*/> Last scan: ${NEW_DATE} | Git: ${NEW_HASH}/" "$INDEX_FILE"
}

update_modules &
```

**Language-specific source globs** (`{source_glob}`):
- Swift: `'*.swift'`
- TypeScript: `'*.ts' '*.tsx'`
- Python: `'*.py'`
- Go: `'*.go'`
- Rust: `'*.rs'`

**Language-specific grep patterns** for the regeneration loop should match FULL_SCAN Step 3 patterns.

### Step 4: Set Permissions & Report

1. Run `chmod +x .git/hooks/post-commit`
2. Print summary:
```
✓ Git post-commit hook installed at .git/hooks/post-commit
  - Triggers after each commit
  - Runs in background (won't slow down commits)
  - Updates only modules with changed files
  - Updates INDEX.md hash automatically

To uninstall: rm .git/hooks/post-commit
```

### Step 5: Update INDEX.md Usage Section

Append to the Usage section in INDEX.md:
```markdown
- **Auto-update**: post-commit hook installed — modules update automatically after each commit
```

---

## Performance Rules

1. **Grep first, Read selectively** — Use Grep to find patterns across files. Only Read individual files when you need to understand function purpose from the body.
2. **Parallel scanning** — Scan multiple modules in parallel using parallel tool calls. For large projects, batch into groups of 3-4 parallel scans.
3. **Don't over-describe** — Function purpose: 3-10 words. If the name is self-explanatory (`loadProfile`, `saveToCache`), keep description minimal.
4. **Skip trivial code** — Don't document: private helper closures, computed properties that are simple getters, standard init() with no logic, protocol stubs with no implementation.
5. **Respect .gitignore** — Skip any paths in .gitignore plus standard exclusions (node_modules, DerivedData, etc.)
6. **Cap per-module size** — If a module has 30+ files, summarize less-important files (group utility functions) rather than listing every signature.
