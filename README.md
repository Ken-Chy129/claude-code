# Claude Code 源码还原与构建

从 `@anthropic-ai/claude-code` v2.1.88 npm 包中的 `cli.js.map` source map 文件还原出的完整源代码，并配置为可编译运行。

## 快速开始

### 环境要求

| 工具 | 版本 | 用途 |
|------|------|------|
| [Bun](https://bun.sh) | v1.3+ | 运行时 & 构建工具 |
| Node.js | v18+ | 部分依赖需要 |

```bash
# 安装 Bun（如果没有）
curl -fsSL https://bun.sh/install | bash
```

### 安装 & 构建

```bash
# 1. 安装依赖（自动创建私有包存根和补丁）
bun install

# 2. 构建
bun run build

# 3. 验证
bun dist/cli.js --version
# 输出: 2.1.88 (Claude Code)
```

### 运行

Claude Code 支持三种认证方式，任选其一：

#### 方式一：Anthropic API Key（最简单）

```bash
ANTHROPIC_API_KEY=sk-ant-xxx bun run start
```

#### 方式二：Google Cloud Vertex AI

```bash
# 前提：已完成 gcloud 登录
gcloud auth application-default login

# 运行
CLAUDE_CODE_USE_VERTEX=1 \
ANTHROPIC_VERTEX_PROJECT_ID=$(gcloud config get-value project) \
CLOUD_ML_REGION=us-east5 \
bun run start
```

可用区域：`us-east5`、`us-central1`、`europe-west1`、`europe-west4` 等（需在 GCP 中开通 Claude 模型）。

#### 方式三：AWS Bedrock

```bash
# 前提：已配置 AWS 凭证
CLAUDE_CODE_USE_BEDROCK=1 \
AWS_REGION=us-east-1 \
bun run start
```

### 便捷配置

将环境变量写入 shell 配置文件（以 Vertex AI 为例）：

```bash
# 添加到 ~/.zshrc 或 ~/.bashrc
export CLAUDE_CODE_USE_VERTEX=1
export ANTHROPIC_VERTEX_PROJECT_ID=your-project-id
export CLOUD_ML_REGION=us-east5

# 创建别名
alias claude="bun /path/to/claude-code/dist/cli.js"
```

之后直接运行 `claude` 即可。

## NPM 脚本

| 命令 | 说明 |
|------|------|
| `bun install` | 安装依赖 + 自动创建存根和补丁 |
| `bun run build` | 构建到 `dist/cli.js`（约 21MB） |
| `bun run start` | 运行构建产物 |
| `bun run dev` | 直接运行源码（开发模式，无需构建） |

## 构建原理

### 为什么需要 Bun？

源码使用 `bun:bundle` 的 `feature()` API 实现编译期特性开关和死代码消除（DCE）：

```typescript
import { feature } from 'bun:bundle'

// 编译时静态替换为 true/false，消除死分支
if (feature('COORDINATOR_MODE')) {
  require('./coordinator/coordinatorMode.js')
}
```

`build.ts` 中通过 Bun 插件将 `feature()` 替换为编译期常量，共 90+ 个特性开关。

### MACRO 常量

源码使用编译期宏（类似 C 的 `#define`）：

```typescript
console.log(`${MACRO.VERSION} (Claude Code)`)  // → "2.1.88 (Claude Code)"
```

在 `build.ts` 的 `define` 中注入。

### 私有包存根

以下 Anthropic 内部包不在公开 npm 上，通过 `scripts/setup-stubs.sh` 创建空实现：

| 包 | 说明 | 存根行为 |
|------|------|----------|
| `color-diff-napi` | 语法高亮 native 模块 | 禁用高亮 |
| `modifiers-napi` | macOS 按键修饰符 | 返回空 |
| `@ant/claude-for-chrome-mcp` | Chrome 扩展 MCP | 空实现 |
| `@anthropic-ai/mcpb` | MCP bundle 处理器 | 返回 null |
| `@anthropic-ai/sandbox-runtime` | 沙盒运行时 | 禁用沙盒 |

### DCE 缺失模块

部分内部模块在原始构建时被 `feature()` 消除，source map 中无源码，通过 `scripts/create-missing-stubs.sh` 创建存根（如 `TungstenTool`、`REPLTool`、`connectorText` 等）。

### Commander 补丁

源码使用 `-d2e` 作为多字符短选项，但 commander v14 只允许单字符。`setup-stubs.sh` 自动将正则从 `/^-[^-]$/` 改为 `/^-[^-]+$/`。

## 源码还原方法

```bash
# 1. 下载 npm 包
npm pack @anthropic-ai/claude-code --registry https://registry.npmjs.org

# 2. 解压
tar xzf anthropic-ai-claude-code-2.1.88.tgz

# 3. 从 source map 还原源码
node -e "
const fs = require('fs');
const path = require('path');
const map = JSON.parse(fs.readFileSync('package/cli.js.map', 'utf8'));
const outDir = './claude-code-source';
for (let i = 0; i < map.sources.length; i++) {
  const content = map.sourcesContent[i];
  if (!content) continue;
  let relPath = map.sources[i];
  while (relPath.startsWith('../')) relPath = relPath.slice(3);
  const outPath = path.join(outDir, relPath);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, content);
}
"
```

## 目录结构

```
.
├── src/                  # 核心源码（1902 个文件）
│   ├── entrypoints/
│   │   └── cli.tsx       # 构建入口点
│   ├── main.tsx          # 主 REPL 逻辑
│   ├── QueryEngine.ts    # AI 对话循环
│   ├── Tool.ts           # 工具类型系统
│   ├── tools/            # 40+ 内置工具（Bash、Edit、Grep...）
│   ├── commands/         # 207 个斜杠命令
│   ├── components/       # 终端 UI 组件（389）
│   ├── ink/              # 自定义 Ink 渲染引擎（96）
│   ├── services/         # 核心服务 — API、MCP、OAuth（130）
│   ├── utils/            # 工具函数（564）
│   └── ...               # 其他模块
├── vendor/               # Native 模块 vendor 源码
├── scripts/              # 构建辅助脚本
│   ├── setup-stubs.sh    # 私有包存根 + 补丁
│   └── create-missing-stubs.sh  # DCE 缺失模块存根
├── build.ts              # Bun 构建脚本
├── package.json          # 依赖 & 脚本
├── tsconfig.json         # TypeScript 配置
└── study/                # 源码学习笔记
    └── 00-architecture-overview.md
```

## 核心模块

| 模块 | 文件数 | 说明 |
|------|--------|------|
| `utils/` | 564 | 工具函数 — 文件 I/O、Git、权限、Diff 等 |
| `components/` | 389 | 终端 UI 组件，基于 Ink 构建 |
| `commands/` | 207 | 斜杠命令 — `/commit`、`/review`、`/diff` 等 |
| `tools/` | 184 | Agent 工具 — Read、Write、Edit、Bash、Glob、Grep 等 |
| `services/` | 130 | 核心服务 — API 客户端、MCP、OAuth、分析 |
| `hooks/` | 104 | React Hooks — 权限、通知、IDE 集成 |
| `ink/` | 96 | 自研终端渲染引擎 — Yoga 布局、事件、选区 |

## 功能可用性

### 完全可用

| 功能 | 说明 |
|------|------|
| 交互式 REPL 对话 | 核心对话循环，流式输出 |
| 40+ 内置工具 | Bash、Read、Write、Edit、Glob、Grep、Agent、WebFetch、WebSearch 等 |
| 200+ 斜杠命令 | `/commit`、`/diff`、`/review`、`/compact`、`/model`、`/help` 等 |
| MCP 服务器 | 标准 stdio/SSE 配置的 MCP 服务器正常连接 |
| 多代理 Swarm | AgentTool 启动子代理、SendMessage 代理间通信 |
| 后台任务管理 | TaskCreate/TaskUpdate/TaskStop 等 |
| CLAUDE.md 记忆系统 | 自动发现和加载项目/用户级 CLAUDE.md |
| 快捷键 & Vim 模式 | 自定义键绑定、Vim 输入模式 |
| 权限系统 | allow/deny 规则、权限弹窗、byass mode |
| 多认证方式 | API Key / Vertex AI / Bedrock |
| 非交互模式 | `--print` 单次查询、管道输入 |
| 会话管理 | `--resume`、`--continue`、会话历史 |
| Git Worktree 隔离 | 子代理在独立 worktree 中工作 |

### 功能降级（私有包缺失）

| 功能 | 原始实现 | 降级后表现 |
|------|----------|-----------|
| 语法高亮 | `color-diff-napi`（native C++ 引擎） | 回退到 `highlight.js`（纯 JS），精度和性能略低 |
| 按键修饰符检测 | `modifiers-napi`（macOS native） | 部分快捷键组合检测失效，基本输入不受影响 |
| 沙盒隔离 | `@anthropic-ai/sandbox-runtime`（Seatbelt/seccomp） | **完全禁用**，Bash 命令直接在宿主系统运行，无文件系统/网络隔离 |
| Chrome 浏览器集成 | `@ant/claude-for-chrome-mcp` | `/chrome` 命令不可用，无法控制浏览器 |
| MCP Bundle 格式 | `@anthropic-ai/mcpb` | 无法加载 `.mcpb` 打包格式，标准 MCP 配置不受影响 |
| 音频采集 | `vendor/audio-capture-src`（native `.node`） | 语音输入不可用（缺少 `.node` 二进制文件） |
| 图片处理 | `vendor/image-processor-src`（native `.node`） | 图片压缩/剪贴板图片不可用 |

### 不可用（被 DCE 删除的内部功能）

| 功能 | Feature Flag | 说明 |
|------|-------------|------|
| 协调器模式 | `COORDINATOR_MODE` | 一个主代理编排多个子代理的高级模式 |
| 助手模式 (KAIROS) | `KAIROS` | 持久后台代理、定时任务、GitHub Webhook |
| 内置 REPL 工具 | 未启用 | 内嵌 Python/JS 执行环境（可用 BashTool 替代） |
| 上下文折叠 | `CONTEXT_COLLAPSE` | 智能隐藏不相关的历史消息 |
| 缓存微压缩 | `CACHED_MICROCOMPACT` | 带缓存的上下文压缩策略 |
| 文件持久化 | `FILE_PERSISTENCE` | 远程环境文件持久化（仅 CCR 环境） |
| 工作流脚本 | `WORKFLOW_SCRIPTS` | 自定义工作流执行 |
| 验证代理 | `VERIFICATION_AGENT` | 计划执行后的自动验证 |
| 语音模式 | `VOICE_MODE` | 语音输入/输出 |
| SSH 远程 | `SSH_REMOTE` | SSH 远程连接管理 |
| Tungsten 工具 | 内部 ant-only | Anthropic 内部监控/调试工具 |

## 统计

| 指标 | 数值 |
|------|------|
| 源文件总数 | 4,756 |
| 核心源码 | 1,906 个文件 |
| 构建产物 | 21.2 MB |
| 特性开关 | 90 个 |
| 包版本 | 2.1.88 |
