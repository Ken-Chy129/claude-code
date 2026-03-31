#!/bin/bash
# 在 bun install 之后运行，创建私有包存根和 commander 补丁
set -e

NODE_MODULES="$(dirname "$0")/../node_modules"

echo "Creating private package stubs..."

# 1. color-diff-napi
mkdir -p "$NODE_MODULES/color-diff-napi"
cat > "$NODE_MODULES/color-diff-napi/package.json" << 'EOF'
{"name":"color-diff-napi","version":"1.0.0","type":"module","main":"index.js","exports":{".":"./index.js"}}
EOF
cat > "$NODE_MODULES/color-diff-napi/index.js" << 'EOF'
export class ColorDiff {
  constructor() {}
  diff() { return [] }
}
export class ColorFile {
  constructor() {}
  getColors() { return [] }
}
export function getSyntaxTheme() { return null }
export const SyntaxTheme = {}
EOF

# 2. modifiers-napi
mkdir -p "$NODE_MODULES/modifiers-napi"
cat > "$NODE_MODULES/modifiers-napi/package.json" << 'EOF'
{"name":"modifiers-napi","version":"1.0.0","type":"module","main":"index.js","exports":{".":"./index.js"}}
EOF
cat > "$NODE_MODULES/modifiers-napi/index.js" << 'EOF'
export function getModifiers() { return [] }
export function isModifierPressed() { return false }
export function prewarm() {}
EOF

# 3. @anthropic-ai/mcpb
mkdir -p "$NODE_MODULES/@anthropic-ai/mcpb"
cat > "$NODE_MODULES/@anthropic-ai/mcpb/package.json" << 'EOF'
{"name":"@anthropic-ai/mcpb","version":"1.0.0","type":"module","main":"index.js"}
EOF
cat > "$NODE_MODULES/@anthropic-ai/mcpb/index.js" << 'EOF'
export function getMcpConfigForManifest() { return null }
EOF

# 4. @anthropic-ai/sandbox-runtime
mkdir -p "$NODE_MODULES/@anthropic-ai/sandbox-runtime"
cat > "$NODE_MODULES/@anthropic-ai/sandbox-runtime/package.json" << 'EOF'
{"name":"@anthropic-ai/sandbox-runtime","version":"1.0.0","type":"module","main":"index.js","exports":{".":"./index.js"}}
EOF
cat > "$NODE_MODULES/@anthropic-ai/sandbox-runtime/index.js" << 'EOF'
import { z } from 'zod'

export const SandboxManager = {
  isSupportedPlatform() { return false },
  checkDependencies() { return { errors: [], warnings: [] } },
  async initialize(_config, callback) { if (callback) await callback() },
  updateConfig(_config) {},
  async reset() {},
  async wrapWithSandbox(_config, fn) { return fn() },
  getFsReadConfig() { return null },
  getFsWriteConfig() { return null },
  getNetworkRestrictionConfig() { return null },
  getIgnoreViolations() { return null },
}

export const SandboxRuntimeConfigSchema = z.object({}).passthrough()

export class SandboxViolationStore {
  add() {}
  getAll() { return [] }
  clear() {}
}
EOF

# 5. @ant/claude-for-chrome-mcp
mkdir -p "$NODE_MODULES/@ant/claude-for-chrome-mcp"
cat > "$NODE_MODULES/@ant/claude-for-chrome-mcp/package.json" << 'EOF'
{"name":"@ant/claude-for-chrome-mcp","version":"1.0.0","type":"module","main":"index.js"}
EOF
cat > "$NODE_MODULES/@ant/claude-for-chrome-mcp/index.js" << 'EOF'
export function createClaudeForChromeMcpServer(ctx) {
  return {
    connect: async () => {},
    close: async () => {},
  }
}
export const BROWSER_TOOLS = []
export class ClaudeForChromeContext {}
export class Logger {}
export class PermissionMode {}
EOF

echo "Patching commander for multi-char short options (-d2e)..."

# 6. Patch commander: allow multi-char short options like -d2e
OPTION_FILE="$NODE_MODULES/commander/lib/option.js"
if [ -f "$OPTION_FILE" ]; then
  # Change /^-[^-]$/ to /^-[^-]+$/ to allow multi-char short options
  sed -i.bak 's|/\^-\[\^-\]\$/|/^-[^-]+$/|g' "$OPTION_FILE"
  rm -f "$OPTION_FILE.bak"
  echo "  commander patched."
else
  echo "  WARNING: commander/lib/option.js not found, skip patch."
fi

# Also patch @commander-js/extra-typings if it has its own option.js
EXTRA_OPTION="$NODE_MODULES/@commander-js/extra-typings/lib/option.js"
if [ -f "$EXTRA_OPTION" ]; then
  sed -i.bak 's|/\^-\[\^-\]\$/|/^-[^-]+$/|g' "$EXTRA_OPTION"
  rm -f "$EXTRA_OPTION.bak"
  echo "  @commander-js/extra-typings patched."
fi

echo "Setting up @anthropic-ai/vertex-sdk core symlink..."

# 7. vertex-sdk needs core/ from sdk (for ../../core/error.mjs imports)
VERTEX_DIR="$NODE_MODULES/@anthropic-ai/vertex-sdk"
SDK_CORE="$(cd "$NODE_MODULES/@anthropic-ai/sdk/core" && pwd)"
if [ -d "$VERTEX_DIR" ] && [ -d "$SDK_CORE" ]; then
  rm -rf "$VERTEX_DIR/core"
  ln -sf "$SDK_CORE" "$VERTEX_DIR/core"
  echo "  vertex-sdk/core -> sdk/core symlinked."
fi

echo "Done! Run 'bun run build' to build."
