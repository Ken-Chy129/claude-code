# Claude Code 源码架构分析

> 基于 v2.1.88 源码，从 source map 还原

## 一、技术栈

| 层面 | 技术 |
|------|------|
| 语言 | TypeScript / TSX |
| 运行时 | Bun（使用 `bun:bundle` 的 `feature()` 做编译期 DCE） |
| UI 框架 | React + 自定义 Ink 引擎（终端 TUI） |
| CLI 框架 | Commander.js（`@commander-js/extra-typings`） |
| AI SDK | `@anthropic-ai/sdk` |
| 构建 | Bun bundler（通过 `MACRO.VERSION` 等编译期宏注入） |

---

## 二、整体架构（分层）

```
┌─────────────────────────────────────────────────────┐
│                  entrypoints/cli.tsx                 │  入口层
│              (快速路径分发 + main.tsx 懒加载)          │
├─────────────────────────────────────────────────────┤
│                     main.tsx                         │  启动编排层
│  (Commander 参数解析 → init → launchRepl/query)      │
├────────────┬────────────────────────────────────────┤
│ screens/   │          commands/                      │  交互层
│ REPL.tsx   │  (207个斜杠命令: /commit, /diff, ...)   │
├────────────┴────────────────────────────────────────┤
│              components/ (389 个文件)                 │  UI 组件层
│  (权限弹窗、消息渲染、Spinner、设置面板、diff视图...)    │
├─────────────────────────────────────────────────────┤
│                ink/ (96 个文件)                       │  渲染引擎层
│  (自定义 Ink fork: Yoga布局、事件系统、选区、焦点...)    │
├─────────────────────────────────────────────────────┤
│   tools/ (40+ 工具)  │  services/ (130 个文件)       │  核心能力层
│   QueryEngine.ts     │  (API、MCP、分析、OAuth...)    │
├──────────────────────┴──────────────────────────────┤
│              utils/ (564 个文件)                      │  基础设施层
│  (git、权限、文件、shell、设置、模型、swarm...)         │
├─────────────────────────────────────────────────────┤
│  state/  │ types/  │ constants/ │ schemas/           │  数据定义层
└─────────────────────────────────────────────────────┘
```

---

## 三、启动流程

```
entrypoints/cli.tsx
  │
  ├─ 快速路径: --version → 直接输出，零模块加载
  ├─ 快速路径: --dump-system-prompt → 输出系统提示词
  ├─ 快速路径: --claude-in-chrome-mcp → 启动 Chrome MCP 服务
  ├─ 快速路径: --daemon-worker → 启动后台工作进程
  │
  └─ 常规路径: 懒加载 main.tsx
       │
       ├─ 并行预取（性能优化）:
       │   ├─ startMdmRawRead()        — MDM 配置子进程
       │   ├─ startKeychainPrefetch()   — macOS 钥匙串读取
       │   ├─ prefetchPassesEligibility — Pass 资格
       │   └─ prefetchFastModeStatus    — 快速模式状态
       │
       ├─ Commander 参数解析
       │   ├─ --print / -p → 非交互式查询模式
       │   ├─ --resume     → 恢复会话
       │   └─ 默认          → 交互式 REPL
       │
       └─ launchRepl() → screens/REPL.tsx
            └─ React 渲染循环（Ink 引擎）
```

---

## 四、核心模块详解

### 4.1 工具系统 (`src/tools/`, `src/Tool.ts`)

**Tool.ts** 定义了工具的核心类型系统：
- `ToolUseContext` — 工具执行上下文（模型、命令、MCP客户端、权限等）
- `ToolPermissionContext` — 权限控制上下文
- `ToolInputJSONSchema` — 工具输入 JSON Schema

**内置工具（40+）：**

| 类别 | 工具 | 说明 |
|------|------|------|
| **文件操作** | FileReadTool, FileWriteTool, FileEditTool, GlobTool, GrepTool | 读、写、编辑、搜索文件 |
| **Shell** | BashTool, PowerShellTool | 执行 shell 命令 |
| **代理** | AgentTool, SendMessageTool | 子代理启动与通信 |
| **任务** | TaskCreateTool, TaskGetTool, TaskListTool, TaskUpdateTool, TaskStopTool, TaskOutputTool | 后台任务管理 |
| **交互** | AskUserQuestionTool | 向用户提问 |
| **网络** | WebFetchTool, WebSearchTool | 网页抓取和搜索 |
| **MCP** | MCPTool, ListMcpResourcesTool, ReadMcpResourceTool, McpAuthTool | MCP 协议工具 |
| **规划** | EnterPlanModeTool, ExitPlanModeTool | 规划模式切换 |
| **工作树** | EnterWorktreeTool, ExitWorktreeTool | Git worktree 隔离 |
| **其他** | NotebookEditTool, SkillTool, ToolSearchTool, ScheduleCronTool, REPLTool, ConfigTool, SleepTool, BriefTool, TodoWriteTool | 笔记本、技能、搜索工具等 |
| **Swarm** | TeamCreateTool, TeamDeleteTool | 多代理团队管理 |
| **远程** | RemoteTriggerTool | 远程触发 |
| **合成** | SyntheticOutputTool | 合成输出（内部） |

### 4.2 查询引擎 (`src/QueryEngine.ts`)

核心 AI 对话循环 — 负责：
- 构建和发送 API 请求
- 处理流式响应
- 工具调用分发
- Token 预算管理
- 上下文压缩（compact）

### 4.3 服务层 (`src/services/`)

| 服务 | 说明 |
|------|------|
| `api/` | Anthropic API 客户端、认证、引导数据 |
| `mcp/` | MCP (Model Context Protocol) 服务端和客户端 |
| `oauth/` | OAuth 2.0 认证流程 |
| `analytics/` | 遥测、DataDog、GrowthBook 特性开关 |
| `compact/` | 上下文压缩服务 |
| `lsp/` | LSP (Language Server Protocol) 集成 |
| `plugins/` | 插件系统 |
| `AgentSummary/` | 代理执行摘要 |
| `MagicDocs/` | 智能文档推荐 |
| `PromptSuggestion/` | 提示词建议 |
| `SessionMemory/` | 会话记忆 |
| `extractMemories/` | 自动记忆提取 |
| `policyLimits/` | 策略限制 |
| `remoteManagedSettings/` | 远程托管设置 |
| `voice.ts` | 语音输入 |

### 4.4 UI 组件层 (`src/components/`)

基于自定义 Ink 引擎的终端 UI：

| 分类 | 代表组件 |
|------|----------|
| **主框架** | App.tsx, Messages.tsx, MessageRow.tsx, VirtualMessageList.tsx |
| **输入** | PromptInput/, TextInput, VimTextInput, BaseTextInput |
| **权限** | permissions/ (Bash/FileEdit/FileWrite 等各类权限弹窗) |
| **消息** | messages/ (各种消息类型的渲染组件) |
| **对话框** | *Dialog.tsx (MCP审批、导出、设置等各种对话框) |
| **Spinner** | Spinner/ (加载动画、闪烁效果) |
| **设计系统** | design-system/ (Dialog, Tabs, ListItem, ThemedText 等) |
| **Diff** | diff/, StructuredDiff, FileEditToolDiff |
| **Logo** | LogoV2/ (启动画面、欢迎页) |
| **代理** | agents/ (代理编辑器、列表、创建向导) |
| **MCP** | mcp/ (MCP 服务管理面板) |
| **任务** | tasks/ (后台任务状态显示) |

### 4.5 自定义 Ink 引擎 (`src/ink/`)

这是 Anthropic 对 Ink (React 终端渲染库) 的深度 fork：

| 模块 | 说明 |
|------|------|
| `dom.ts` | 虚拟 DOM 节点 |
| `reconciler.ts` | React Reconciler 适配 |
| `layout/` | Yoga 布局引擎（engine, geometry, node） |
| `output.ts` | 终端输出缓冲 |
| `renderer.ts` | 渲染管线 |
| `screen.ts` | 全屏管理 |
| `selection.ts` | 文本选区 |
| `focus.ts` | 焦点管理 |
| `events/` | 事件系统（click, keyboard, focus, input） |
| `termio/` | 终端 I/O (ANSI/CSI/SGR/OSC 解析) |
| `hooks/` | use-input, use-selection, use-terminal-viewport 等 |
| `components/` | Box, Text, ScrollBox, Button, Link 等基础组件 |

### 4.6 工具函数层 (`src/utils/`, 564 个文件)

| 分类 | 说明 |
|------|------|
| `git/` | Git 操作封装 |
| `github/` | GitHub API 封装 |
| `bash/`, `shell/`, `powershell/` | Shell 执行与解析 |
| `permissions/` | 权限检查与规则匹配 |
| `settings/` | 配置文件加载（包括 MDM） |
| `model/` | 模型选择与配置 |
| `swarm/` | 多代理 Swarm 协调 |
| `memory/` | 自动记忆系统 |
| `mcp/` | MCP 工具函数 |
| `plugins/` | 插件加载与管理 |
| `sandbox/` | 沙盒隔离 |
| `secureStorage/` | 钥匙串/安全存储 |
| `teleport/` | 会话传送 |
| `skills/` | 技能系统 |
| `task/` | 任务调度 |
| `telemetry/` | 遥测追踪 |
| `background/` | 后台作业 |
| `computerUse/` | 计算机使用 (Computer Use) |
| `claudeInChrome/` | Chrome 扩展集成 |
| `hooks/` | 生命周期钩子执行 |

### 4.7 其他关键模块

| 模块 | 文件数 | 说明 |
|------|--------|------|
| `commands/` | 207 | 斜杠命令 — 每个命令一个目录（index.ts + 实现文件） |
| `hooks/` | 104 | React Hooks — 通知、权限、IDE 集成、键绑定等 |
| `bridge/` | 31 | 远程桥接 — REPL Bridge、WebSocket、JWT |
| `keybindings/` | 14 | 快捷键系统 — 解析、匹配、校验 |
| `memdir/` | 8 | 记忆目录 — CLAUDE.md 文件管理 |
| `skills/` | 20 | 技能系统 — 技能加载、匹配、执行 |
| `tasks/` | 12 | 后台任务类型 — Shell、Agent、Dream 等 |
| `state/` | 6 | 应用状态 — AppState、全局状态管理 |
| `migrations/` | 11 | 数据迁移 — 配置和模型升级 |
| `coordinator/` | 1 | 协调器模式（多代理编排） |
| `buddy/` | 6 | 伴侣精灵（桌面端动画角色） |
| `vim/` | 5 | Vim 模式输入 |

---

## 五、关键数据流

### 5.1 用户输入 → AI 响应

```
PromptInput (用户输入)
  → processUserInput (解析命令/文本)
    → 如果是 /command → 执行对应 Command
    → 如果是普通文本 → QueryEngine.query()
      → 构建 messages[] + system prompt
      → Anthropic API 调用（流式）
      → 解析 tool_use blocks → 分发到对应 Tool
      → Tool 执行 → tool_result 回传
      → 继续对话循环直到 stop_reason=end_turn
```

### 5.2 权限检查流

```
工具调用
  → ToolPermissionContext 检查
    → alwaysAllowRules 匹配 → 直接执行
    → alwaysDenyRules 匹配 → 拒绝
    → 否则 → PermissionRequest 组件弹窗
      → 用户选择 Allow/Deny
      → 可选 "Always allow" 持久化规则
```

### 5.3 Swarm（多代理协作）

```
主代理 (Leader)
  ├─ TeamCreateTool → 创建子代理团队
  ├─ AgentTool → 启动子代理（可选 worktree 隔离）
  ├─ SendMessageTool → 代理间通信
  └─ 权限桥接 → 子代理权限请求代理到主代理 UI
```

---

## 六、Feature Flags 与条件编译

代码使用 `feature()` from `bun:bundle` 实现编译期死代码消除（DCE）：

```typescript
// 只在内部版本中编译
if (feature('COORDINATOR_MODE')) { ... }
if (feature('KAIROS')) { ... }        // 助理模式
if (feature('DAEMON')) { ... }        // 后台守护进程
if (feature('CHICAGO_MCP')) { ... }   // Computer Use MCP
if (feature('DUMP_SYSTEM_PROMPT')) { ... }
if (feature('ABLATION_BASELINE')) { ... }
```

---

## 七、建议阅读路线

### 路线 A：理解核心 AI 对话循环
1. `src/entrypoints/cli.tsx` — 入口分发
2. `src/main.tsx` — 启动编排（前 200 行）
3. `src/QueryEngine.ts` — 核心对话循环
4. `src/Tool.ts` — 工具类型系统
5. `src/tools/BashTool/` — 一个典型工具实现
6. `src/constants/prompts.ts` — 系统提示词

### 路线 B：理解 UI 渲染
1. `src/screens/REPL.tsx` — 主屏幕
2. `src/components/App.tsx` — 应用骨架
3. `src/components/Messages.tsx` — 消息列表
4. `src/components/PromptInput/PromptInput.tsx` — 输入框
5. `src/ink/` — 自定义渲染引擎

### 路线 C：理解权限与安全
1. `src/types/permissions.ts` — 权限类型
2. `src/utils/permissions/` — 权限规则匹配
3. `src/hooks/toolPermission/` — 权限 Hook
4. `src/components/permissions/` — 权限 UI
5. `src/utils/sandbox/` — 沙盒隔离

### 路线 D：理解多代理系统
1. `src/tools/AgentTool/` — 子代理启动
2. `src/utils/swarm/` — Swarm 协调
3. `src/tasks/` — 后台任务类型
4. `src/coordinator/coordinatorMode.ts` — 协调器模式
