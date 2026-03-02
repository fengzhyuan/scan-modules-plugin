# scan-modules

[English](./README.md) | 中文

一个 Claude Code 插件，扫描代码库的模块结构、类型声明和函数签名，缓存到本地 `.md` 文件中，让 Claude 在每次会话开始时快速加载项目上下文。

## 为什么需要

Claude Code 在会话之间会丢失项目上下文。这个插件创建一个轻量级的模块缓存，Claude 只需几秒就能读取，而不必每次都重新探索整个代码库。

**之前**：Claude 每次开会话要花 30-60 秒 grep 来理解项目结构。
**之后**：Claude 读一个 INDEX.md（约 80 行）就掌握所有模块、文件和函数。

## 功能

- **全量扫描** — 发现所有模块，提取类型和函数签名，生成模块文档
- **增量更新** — 只重新扫描有变更的模块（通过 git diff）
- **状态检查** — 查看哪些模块缓存已过期
- **Git Hook** — 每次 commit 后自动更新模块文档
- **多语言支持** — Swift、TypeScript/JavaScript、Python、Go、Rust
- **自动加载** — 安装后 Claude 自动在会话开始时读取模块缓存

## 安装

```bash
# 从 GitHub 安装
/plugin install <github-url>

# 或本地测试
claude --plugin-dir ./scan-modules-plugin
```

## 使用

```bash
# 首次：全量扫描项目
/scan-modules:scan-modules

# 查看哪些模块需要更新
/scan-modules:scan-modules status

# 只更新有变更的模块
/scan-modules:scan-modules update

# 更新指定模块
/scan-modules:scan-modules update vision

# 安装 git post-commit hook，自动更新
/scan-modules:scan-modules install-hook
```

## 生成内容

```
.claude/modules/
  INDEX.md              # 主索引：所有模块、依赖图、使用说明
  auth.md               # 模块详情：类型、函数签名、依赖关系
  blockchain.md
  vision.md
  ...
```

### INDEX.md（约 80 行）

所有模块的快速概览，包含文件数量和描述。会话开始时读取。

```markdown
<!-- SCAN_META: hash=abc1234 date=2026-03-02 -->
# Project Modules — MyApp
> Type: iOS/macOS | Language: Swift (SwiftUI)
> Modules: 36 | Files: 192

## Modules
| Module | Path | Files | Description |
|--------|------|-------|-------------|
| auth   | Services/Auth | 1 | JWT 认证和会话管理 |
| vision | Services/Vision | 13 | 端侧 AI 流水线 |
...
```

### 模块详情文件

每个模块的函数级参考文档。

```markdown
# Module: Vision
> Path: Services/Vision | Files: 13

## Files

### VisionAnalyzer.swift
**Type**: `class VisionAnalyzer` | **Purpose**: 图像分类和人脸检测

| Visibility | Signature | Purpose |
|------------|-----------|---------|
| internal | `func analyze(_ image: UIImage) async -> ImageAnalysisResult` | 运行 Vision 框架 |

## Dependencies
- **Uses**: CoreML, Vision
- **Used by**: LazyNoteView, StorybookLayoutView
```

## 工作原理

1. **检测项目类型** — 通过标记文件（Package.swift、package.json、Cargo.toml 等）
2. **发现模块** — 按目录层级扫描
3. **Grep 提取签名** — 类型、函数、Published 属性（不读取完整文件）
4. **生成 .md 文件** — 统一模板格式
5. **跟踪新鲜度** — 通过 SCAN_META 注释中的 git hash

## 支持的语言

| 语言 | 类型模式 | 函数模式 |
|------|---------|---------|
| Swift | `class/struct/protocol/actor/enum` | `func` |
| TypeScript | `class/interface/type/enum` | `function`、`export const` |
| Python | `class` | `def`、`async def` |
| Go | `type ... struct/interface` | `func` |
| Rust | `struct/enum/trait` | `fn`、`pub fn` |

## Git Hook

`/scan-modules:scan-modules install-hook` 安装 post-commit hook：
- 后台运行（不影响 commit 速度）
- 只重新生成有变更的模块
- 自动更新 INDEX.md 的 hash

## 插件结构

```
scan-modules-plugin/
├── .claude-plugin/
│   └── plugin.json                # 插件元数据
├── commands/
│   └── scan-modules.md            # 手动调用：/scan-modules:scan-modules
├── skills/
│   └── auto-context/
│       └── SKILL.md               # 自动调用：读 INDEX.md + 检查 freshness
└── README.md
```

| 组件 | 触发方式 | 功能 |
|------|---------|------|
| `skills/auto-context` | 自动 — 每次会话开始 | 读取 INDEX.md，加载项目结构，检查缓存是否过期 |
| `commands/scan-modules` | 手动 — `/scan-modules:scan-modules` | 全量扫描 / 增量更新 / 状态检查 / 安装 hook |

## 提示

- 把 `.claude/modules/` 加到 `.gitignore` — 这些是本地缓存文件
- 会话开始时读 `INDEX.md` 了解项目全貌
- 需要时按需读取模块详情文件
- 定期运行 `status` 检查新鲜度

## License

MIT
