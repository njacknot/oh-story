# 升级指南

## 升级策略

| 策略 | 适用场景 | 风险 |
|------|----------|------|
| 覆盖部署 | 全新项目或无需保留自定义 | 低 |
| 合并部署 | 有自定义内容需保留 | 中 |
| 手动更新 | 只改特定文件 | 低 |

推荐：运行 `/story-setup` 重新部署，自动走合并策略。

## 文件分类

### 可安全覆盖

这些文件由 story-setup 管理，不含用户自定义内容：
- `.claude/hooks/` — 所有 hook 脚本
- `.claude/agents/` — 所有 agent 定义
- `.claude/rules/` — 所有 path-scoped 规则
- `.codex/agents/` — 所有 Codex 原生 agent TOML 定义
- `.oh-story-codex/` — 项目内置 skill 包（用于 Trae SOLO / Cloud Agents）

### 需合并（不覆盖）

这些文件可能含用户自定义内容：
- `CLAUDE.md` — 按 section 合并，用户独有 section 保留
- `AGENTS.md` — 按 `OH-STORY-CODEX` 托管区块合并，用户区块保留
- `.claude/settings.local.json` — hooks 按 command 去重 append，其他配置保留
- `.codex/config.toml` — 只补充缺失的 `[agents]` 并发/深度配置，用户已有值保留

### 不碰

这些文件完全由用户管理：
- `{书名}/追踪/上下文.md` — 用户写作上下文
- `{书名}/追踪/伏笔.md` — 用户伏笔追踪
- `.active-book` — 用户活跃书目

## 版本检测

`.story-deployed` 文件记录部署版本：
- 无此文件 → 未部署，需全新安装
- `agents_version: 1` → 旧版，需重新部署以获取新 Agent
- `agents_version: 2` → 旧版，需重新部署以获取 story-explorer agent
- `agents_version: 3` → 旧版，需重新部署以获取 story-explorer agent
- `agents_version: 4` → 旧版，需重新部署以获取 chapter-extractor agent
- `agents_version: 5` → 旧版，需重新部署以统一短篇主会话/子代理正文格式
- `agents_version: 6` → 旧版，需重新部署以获取日更续写与伏笔 hook 修复
- `agents_version: 7` → 旧版，需重新部署以获取 Agent 参考文件路径修复
- `agents_version: 8` → 旧版，需重新部署以获取 Codex 原生子代理配置
- `agents_version: 8` + `projectized_skill_version: 1` → 旧版，需重新部署以获取 Codex 原生子代理配置
- `agents_version: 9` + `projectized_skill_version: 2` + `codex_agents_version: 1` → 当前版本

## 版本变更

### v2

- 4 个创作型 Agent + 1 个研究型 Agent（story-architect, character-designer, narrative-writer, consistency-checker, story-researcher）
- Agent 引用 skill references 写作理论
- Hook 脚本优化（减少 context 输出）
- 4 条 path-scoped 规则

### v3

- 新增 story-explorer 只读查询 Agent（角色/伏笔/设定/进度查询，日更上下文快速加载）
- 6 个 Agent 总计（story-architect, character-designer, narrative-writer, consistency-checker, story-researcher, story-explorer）
- story-explorer 被 story-long-write、story-review、story 路由集成调用

### v4

- 新增 chapter-extractor 章节提取 Agent
- 7 个 Agent 总计（story-architect, character-designer, narrative-writer, consistency-checker, story-researcher, story-explorer, chapter-extractor）

### v5

- 更新 narrative-writer 场景写法：使用“三维度织入”并按镜头断段控制段落密度
- 字数统计改为 Python 字符统计优先，`wc -m` 仅作 macOS/Linux 备选，提升 Windows + DeepSeek/Claude Code 兼容性
- 已部署项目重新运行 `/story-setup` 后获取新版 agent 定义

### v6

- 统一 narrative-writer 子代理与主会话的短篇正文格式：固定写入 `正文.md`、小节标记统一、段落无空行、对话半角双引号
- 短篇写作不再由 narrative-writer 创建长篇 `追踪/上下文.md`

### v7

- 修复长篇 `/story-long-write 日更` 批量续写中的 continuation 规则：同一批次内“继续/续写/日更”保持在 daily workflow，不直接跳到正文续写。
- 修复 `detect-story-gaps.sh` 对伏笔表头和正常开放伏笔（`未埋`/`已埋`）的误报；SessionStart 只提示 `已过期` 或异常状态。
- 已部署项目需重新运行 `/story-setup`，以覆盖 `.claude/hooks/`、`.claude/agents/`、`.claude/rules/` 并获得新版 hook 行为。

### v8

- 修复 story-review 及部署后的 reviewer Agent 在项目根目录下读取参考文件时，只找裸文件名（如 `quality-checklist.md`）导致找不到 skill references 的问题。
- Agent 模板新增参考文件路径规则：优先从 `.claude/skills/` 或 `skills/` 拼接解析 `story-setup/references/agent-references/*.md` 规范路径，避免依赖当前工作目录且不跨 skill 引用 references。
- 已部署项目需重新运行 `/story-setup`，以覆盖 `.claude/agents/` 并获得新版参考文件路径规则。

### v9 (当前)

- 新增 chapter-editor 单章主编 Agent
- story-long-write 单章写作在字数验证、基础检查、禁用词扫描后执行 chapter-editor 复审
- 日更模式逐章支持 chapter-editor 复审，REVISE/REWRITE 时修订后重新验字数
- story-setup 新增项目化部署：复制 oh-story-codex 到项目根 `.oh-story-codex/`，并生成/合并 `AGENTS.md`
- 新增 `scripts/deploy-projectized.sh`，用于稳定执行 `.oh-story-codex/` 复制和 `AGENTS.md` 托管区块合并
- Trae SOLO / Cloud Agents 可通过 `AGENTS.md` 使用项目内置 skill，不依赖全局 skill 安装

### v9 (当前)

- 新增 Codex 原生 `.codex/agents/*.toml` 模板，覆盖 8 个 story agent：story-architect、character-designer、narrative-writer、chapter-editor、consistency-checker、story-researcher、story-explorer、chapter-extractor
- 新增 `.codex/config.toml` 基础配置，默认 `max_threads = 4`、`max_depth = 1`
- `deploy-projectized.sh` 在部署 `.oh-story-codex/` 与 `AGENTS.md` 时同步部署 `.codex/agents/`，并安全合并 `.codex/config.toml`
- `AGENTS.md` 增加 Codex 原生子代理调用规则，明确 Codex 需要显式要求 spawn 子代理
