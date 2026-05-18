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
- `.oh-story-codex/` — 项目内置 skill 包（用于 Trae SOLO / Cloud Agents）

### 需合并（不覆盖）

这些文件可能含用户自定义内容：
- `CLAUDE.md` — 按 section 合并，用户独有 section 保留
- `AGENTS.md` — 按 `OH-STORY-CODEX` 托管区块合并，用户区块保留
- `.claude/settings.local.json` — hooks 按 command 去重 append，其他配置保留

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
- `agents_version: 3` → 旧版，需重新部署以获取 chapter-extractor agent
- `agents_version: 4` → 旧版，需重新部署以获取 chapter-editor agent
- `agents_version: 5` + `projectized_skill_version: 1` → 当前版本

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

- 新增 chapter-extractor Agent
- story-long-analyze / story-import 的逐章摘要阶段支持每批 5-8 个 chapter-extractor 并行处理
- 单章失败不阻断管线，失败记录到 `_progress.md` 并重试

### v5 (当前)

- 新增 chapter-editor 单章主编 Agent
- story-long-write 单章写作在字数验证、基础检查、禁用词扫描后执行 chapter-editor 复审
- 日更模式逐章支持 chapter-editor 复审，REVISE/REWRITE 时修订后重新验字数
- story-setup 新增项目化部署：复制 oh-story-codex 到项目根 `.oh-story-codex/`，并生成/合并 `AGENTS.md`
- 新增 `scripts/deploy-projectized.sh`，用于稳定执行 `.oh-story-codex/` 复制和 `AGENTS.md` 托管区块合并
- Trae SOLO / Cloud Agents 可通过 `AGENTS.md` 使用项目内置 skill，不依赖全局 skill 安装
