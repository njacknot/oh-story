---
name: story-setup
version: 1.0.0
description: |
  网文写作工具集基础设施部署。将本地 .oh-story-codex、AGENTS.md、.codex/agents、hooks/rules/agents/CLAUDE.md 等基础设施部署到用户项目目录。
  触发方式：/story-setup、「准备写书」「帮我搭一下环境」「配置写作项目」
metadata:
  openclaw:
    source: https://github.com/worldwonderer/oh-story-claudecode
---

# story-setup：网文写作工具集基础设施部署

你是写作基础设施部署器。将网文写作工具集的全套基础设施（本地 `.oh-story-codex/`、`AGENTS.md`、Codex 原生 `.codex/agents/`、hooks、rules、agents、CLAUDE.md）部署到用户项目目录。

**执行铁律：不覆盖用户已有配置，合并而非替换。**

---

## Phase 1：检测项目状态

1. 检查当前目录是否已部署过（存在 `.story-deployed`）
   - 如果已存在 → 使用 AskUserQuestion 确认是否重新部署
2. 检查是否有书名目录（包含 `追踪/` 子目录的目录，或用户自定义结构）
   - 有 → 识别为长篇项目，显示当前项目信息
   - 无 → 识别为新项目或短篇项目
3. 检查 `.claude/settings.local.json` 是否存在
   - 存在 → 读取现有配置，后续合并
   - 不存在 → 后续创建新文件
4. 检查 `.active-book` 文件是否存在
   - 存在 → 显示当前活跃书目
   - 不存在 → 跳过
5. 检查 `.oh-story-codex/` 是否存在
   - 存在 → 显示本地化 skill 包已部署
   - 不存在 → 后续从当前 oh-story-codex skill 包复制
6. 检查 `AGENTS.md` 是否存在
   - 存在 → 后续按「AGENTS.md 合并策略」处理
   - 不存在 → 后续创建新文件
7. 检查 `.codex/agents/` 是否存在
   - 存在 → 后续安全覆盖 story-setup 管理的 Codex agent TOML
   - 不存在 → 后续创建并部署 Codex agent TOML
8. 检查 `.codex/config.toml` 是否存在
   - 存在 → 后续只补充缺失的 `[agents]` 并发/深度配置，不覆盖用户已有值
   - 不存在 → 后续创建 Codex 子代理基础配置

## Phase 2：部署基础设施

使用 AskUserQuestion 确认部署位置后，依次执行：

### 2.1 部署项目化 Skill 包

- 优先运行脚本：
  `skills/story-setup/scripts/deploy-projectized.sh <用户项目根目录> <当前 oh-story-codex 包根目录>`
- 定位当前 oh-story-codex 包根目录：从 `skills/story-setup/SKILL.md` 向上两级找到包含 `skills/`、`README.md` 的目录
- 复制整个包到用户项目根目录 `.oh-story-codex/`
- 复制时排除 `.git/`、`.DS_Store`、`node_modules/`、临时文件和用户项目正文目录
- 如果 `.oh-story-codex/` 已存在：
  - 默认增量覆盖 skill 包自身文件
  - 不删除用户在 `.oh-story-codex/` 下额外添加的文件
  - 如用户明确要求干净重装，才先备份再替换
- 目的：让 Trae SOLO、Cloud Agents、Codex/Claude 等不支持全局 skill 安装的运行环境也能读取项目内置 skill
- 此脚本同时部署 Codex 原生 `.codex/agents/*.toml` 和 `.codex/config.toml` 的最低子代理配置

### 2.2 部署 AGENTS.md

- 如果 2.1 已运行 `deploy-projectized.sh`，AGENTS.md 与 `.codex/agents/` 已由脚本创建或合并，本步骤只需验证
- 读取 `skills/story-setup/references/templates/AGENTS.md.tmpl`
- 替换占位符
- 写入项目根目录 `AGENTS.md`（如已存在，按「AGENTS.md 合并策略」处理）
- `AGENTS.md` 负责约束 Trae SOLO 或其他 Cloud Agents：优先读取 `.oh-story-codex/`，按本地 skill 工作流执行

### 2.3 部署 CLAUDE.md
- 读取 `skills/story-setup/references/templates/CLAUDE.md.tmpl`
- 替换占位符（见下方「模板占位符」段）
- 写入项目根目录 `CLAUDE.md`（如已存在，按「CLAUDE.md 合并策略」处理）

### 2.4 部署 Hooks
- 读取 `skills/story-setup/references/templates/hooks/` 下所有 `.sh` 文件
- 复制到用户项目的 `.claude/hooks/` 目录
- 确保脚本有执行权限（chmod +x）

### 2.5 部署 Rules
- 读取 `skills/story-setup/references/templates/rules/` 下所有 `.md` 文件
- 复制到用户项目的 `.claude/rules/` 目录

### 2.6 部署 Agents
- 读取 `skills/story-setup/references/templates/agents/` 下所有 `.md` 文件
- 复制到用户项目的 `.claude/agents/` 目录
- Agent 文件属于 story-setup 管理文件，可安全覆盖；版本升级时按 `UPGRADING.md` 的版本检测结果重新部署


### 2.6.1 Agent 兼容性处理
- Agent frontmatter 以 Claude Code 为主；OpenClaw/qclaw 等只要支持 AgentSkills，未知字段（如 `memory`、`skills`、`disallowedTools`）应被忽略。若目标工具报 frontmatter 错误，保留 `name`、`description`、`tools` 三项，删除不支持字段后再部署。
- 部署到项目后，agent 内引用的参考资料必须走 `story-setup/references/agent-references/*.md` 这一本 skill 内复制路径；不要跨 skill 引用其他 skill 的 references。若全局安装路径不同，优先用项目内 `.claude/skills/` 或 `skills/` 作为规范路径前缀，其次用工具的 skill 搜索能力，不要假定固定绝对路径。

### 2.7 部署 Codex 原生 Agents
- 读取 `skills/story-setup/references/templates/codex/agents/` 下所有 `.toml` 文件
- 复制到用户项目的 `.codex/agents/` 目录
- Codex agent TOML 属于 story-setup 管理文件，可安全覆盖
- 读取 `skills/story-setup/references/templates/codex/config.toml.tmpl`
- 如果 `.codex/config.toml` 不存在，创建基础配置：
  ```toml
  [agents]
  max_threads = 4
  max_depth = 1
  ```
- 如果 `.codex/config.toml` 已存在，只在 `[agents]` 表内补充缺失的 `max_threads` / `max_depth`；用户已有值不覆盖
- Codex 原生 agent 名称与 Claude agent 保持一致：`story-architect`、`character-designer`、`narrative-writer`、`chapter-editor`、`consistency-checker`、`story-researcher`、`story-explorer`、`chapter-extractor`

### 2.8 部署 Session State 模板
- 读取 `skills/story-setup/references/templates/上下文.md.tmpl`
- 如有书名目录，复制到 `{书名}/追踪/` 下

### 2.9 合并 Hooks 注册到 settings.local.json

> 兼容性说明：`settings-hooks.json` 中 PreToolUse 的 `if` 字段使用 Claude Code hook 条件语法，需要运行环境支持 hook-level if。若目标工具不支持该字段，hook 脚本本身仍会自检并 advisory-only 退出；部署时可删除该 `if` 字段并保留 matcher + command。

- 读取 `skills/story-setup/references/templates/settings-hooks.json`
- 读取用户项目的 `.claude/settings.local.json`（如存在）
- 合并 hooks 配置（按「settings-hooks.json 合并算法」处理）
- 写入 `.claude/settings.local.json`

### 2.10 创建部署标记

- 创建 `.story-deployed` 文件（sentinel file）
- 写入以下字段：
  ```
  deployed_at: <date -u +"%Y-%m-%dT%H:%M:%SZ">
  agents_version: 9
  projectized_skill_version: 2
  codex_agents_version: 1
  setup_skill_version: 1.0.0
  ```
- 此文件供 session-start.sh 和写作 skill 检测部署状态，避免重复提示
- 如果 `.story-deployed` 已存在但无 `agents_version` 或版本 < 9，提示用户重新运行 story-setup 以更新 hooks/agents/rules（v9 新增 Codex 原生子代理并保留项目化部署与 chapter-editor；v8 修复 Agent 读取 skill 参考文件路径；v7 修复日更续写 continuation 与伏笔 hook 误报；v6 统一短篇主会话/子代理正文格式；v5 更新 narrative-writer 场景写法、段落密度规则和跨平台字数统计）
- 如果 `.story-deployed` 已存在但无 `projectized_skill_version` 或版本 < 2，提示用户重新运行 story-setup 以部署 `.oh-story-codex/`、`AGENTS.md` 和 `.codex/agents/`
- 如果 `.story-deployed` 已存在但无 `codex_agents_version`，提示用户重新运行 story-setup 以补充 Codex 原生子代理配置

## Phase 3：验证安装

1. 验证 hooks 注册：
   - 检查 `.claude/settings.local.json` 中的 hooks 字段是否正确
   - 检查 `.claude/hooks/` 下的脚本是否存在且有执行权限
2. 验证 rules 路径：
   - 检查 `.claude/rules/` 下的规则文件是否存在且包含 `paths` frontmatter
3. 验证 agents：
   - 检查 `.claude/agents/` 下的 agent 定义文件是否存在
4. 验证项目化 skill：
   - 检查 `.oh-story-codex/skills/story/SKILL.md` 是否存在
   - 检查 `AGENTS.md` 是否存在且包含 `OH-STORY-CODEX:BEGIN`
5. 验证 Codex 原生子代理：
   - 检查 `.codex/config.toml` 是否存在且包含 `[agents]`
   - 检查 `.codex/agents/story-architect.toml`、`.codex/agents/narrative-writer.toml`、`.codex/agents/chapter-editor.toml` 是否存在
6. 验证部署标记：
   - 检查 `.story-deployed` 是否存在且包含时间戳
7. 输出安装报告：
   - 列出所有已部署的文件
   - 列出需要注意的事项（如已有配置已合并）
   - 提示用户可以开始使用 `/story-long-write` 或 `/story-short-write`

---

## 模板占位符

| 占位符 | 替换规则 | 示例 |
|--------|----------|------|
| `{项目名}` | 用户项目名称或目录名 | 《剑来》、《暗卫》 |
| `{书名}` | 书名目录名（与目录一致） | 与 `{项目名}` 相同，或用户自定义 |
| `{目标平台}` | 目标发布平台 | 起点、番茄、晋江、知乎盐言 |
| `{作者名}` | 用户笔名或昵称 | 未指定时用「作者」 |

替换时去掉花括号。如果用户未指定项目名，用当前目录名。未指定的占位符保留原样不替换。

## CLAUDE.md 合并策略

用户已有 CLAUDE.md 时，按 section 合并：
1. 读取用户现有 CLAUDE.md，按 `##` 标题切分为 section map
2. 读取模板 CLAUDE.md.tmpl，同样切分
3. 模板中的标准 section（Skill 路由表、文件结构、协作规则、Context Recovery、语言）**覆盖**用户同名 section
4. 用户独有的 section（自定义内容）**保留**不动
5. 未知冲突用 AskUserQuestion 让用户选择保留哪个版本

## AGENTS.md 合并策略

用户已有 AGENTS.md 时，按托管区块合并：
1. 读取用户现有 AGENTS.md
2. 如果存在 `<!-- OH-STORY-CODEX:BEGIN -->` 与 `<!-- OH-STORY-CODEX:END -->`，用模板生成的新区块替换旧区块
3. 如果不存在托管区块，将模板内容追加到文件末尾，并保留用户原有内容
4. 用户在托管区块外的内容完整保留

## settings-hooks.json 合并算法

hooks 注册合并按 command 字段去重：
1. 读取用户现有 `.claude/settings.local.json`（如存在），提取 hooks 部分
2. 读取 `settings-hooks.json` 模板，提取要注册的 hooks
3. 对每个 hook event（SessionStart、PreToolUse 等）：
   - 用户已有的 hook command → 保留，不重复添加
   - 模板中的新 hook command → append 到对应 event 的 hooks 数组
   - 用户独有的其他配置（permissions、env 等）→ 完整保留
4. 写入合并后的完整 settings.local.json

## 重新部署

- `.story-deployed` 不存在 → 全新安装，Phase 2 全部执行
- `.story-deployed` 存在且 `agents_version: 9` 且 `projectized_skill_version: 2` 且 `codex_agents_version: 1` → 提示已部署，AskUserQuestion 确认是否重新部署
- `.story-deployed` 存在但 `agents_version` < 9 → 提示需要更新，重新执行 Phase 2 覆盖 agents/hooks/rules，CLAUDE.md、AGENTS.md、`.codex/agents/` 和 settings.local.json 走合并策略
- `.story-deployed` 存在但没有 `projectized_skill_version` 或版本 < 2 → 提示需要补充项目化部署，执行 2.1、2.2、2.7、2.10，并验证 `.oh-story-codex/`、`AGENTS.md` 与 `.codex/agents/`
- `.story-deployed` 存在但没有 `codex_agents_version` → 提示需要补充 Codex 原生子代理，执行 2.7、2.10

---

## 参考资料

| 文件 | 用途 |
|------|------|
| references/templates/CLAUDE.md.tmpl | 项目根 CLAUDE.md 模板 |
| references/templates/AGENTS.md.tmpl | 项目根 AGENTS.md 模板，约束 Trae SOLO / Cloud Agents 使用 `.oh-story-codex/` |
| scripts/deploy-projectized.sh | 复制 `.oh-story-codex/` 并创建/合并 `AGENTS.md` |
| references/templates/codex/config.toml.tmpl | Codex 项目级子代理基础配置 |
| references/templates/codex/agents/ | 8 个 Codex 原生 agent TOML 定义 |
| references/templates/hooks/ | 6 个 hook 脚本模板 |
| references/templates/rules/ | 4 条 path-scoped 规则模板 |
| references/templates/agents/ | 8 个 agent 定义模板（story-architect, character-designer, narrative-writer, chapter-editor, consistency-checker, story-researcher, story-explorer, chapter-extractor） |
| references/agent-references/ | Agent 模板自带的参考资料副本；模板只引用本目录，避免跨 skill references |
| references/templates/settings-hooks.json | hooks 注册 JSON 片段 |
| references/templates/上下文.md.tmpl | 写作上下文模板 |
