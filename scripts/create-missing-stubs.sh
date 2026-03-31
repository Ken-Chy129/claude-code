#!/bin/bash
# Create stub files for modules that were DCE'd from the source map
set -e
cd "$(dirname "$0")/.."

echo "Creating missing source stubs..."

# --- Internal types ---
mkdir -p src/types
cat > src/types/connectorText.ts << 'EOF'
export type ConnectorTextBlock = {
  type: 'connector_text'
  text: string
}
export function isConnectorTextBlock(block: unknown): block is ConnectorTextBlock {
  return typeof block === 'object' && block !== null && (block as any).type === 'connector_text'
}
EOF

# --- Protected namespace ---
cat > src/utils/protectedNamespace.ts << 'EOF'
export function isProtectedNamespace(_ns: string): boolean {
  return false
}
EOF

# --- TungstenTool (internal ant-only tool) ---
mkdir -p src/tools/TungstenTool
cat > src/tools/TungstenTool/TungstenTool.ts << 'EOF'
export const TungstenTool = {
  name: 'tungsten',
  description: 'Internal tool (stub)',
  async call() { return { output: '' } },
}
EOF
cat > src/tools/TungstenTool/TungstenLiveMonitor.tsx << 'EOF'
import React from 'react'
export function TungstenLiveMonitor() { return null }
EOF

# --- REPLTool (internal, behind feature flag) ---
mkdir -p src/tools/REPLTool
cat > src/tools/REPLTool/REPLTool.ts << 'EOF'
export const REPLTool = null
EOF
cat > src/tools/REPLTool/constants.ts << 'EOF'
export const REPL_TOOL_NAME = 'repl'
export const REPL_TOOL_ALLOWED_LANGUAGES = ['python', 'javascript', 'typescript']
export function isReplModeEnabled(): boolean { return false }
EOF

# --- SuggestBackgroundPRTool ---
mkdir -p src/tools/SuggestBackgroundPRTool
cat > src/tools/SuggestBackgroundPRTool/SuggestBackgroundPRTool.ts << 'EOF'
export const SuggestBackgroundPRTool = null
EOF

# --- VerifyPlanExecutionTool ---
mkdir -p src/tools/VerifyPlanExecutionTool
cat > src/tools/VerifyPlanExecutionTool/VerifyPlanExecutionTool.ts << 'EOF'
export const VerifyPlanExecutionTool = null
EOF

# --- WorkflowTool ---
mkdir -p src/tools/WorkflowTool
cat > src/tools/WorkflowTool/constants.ts << 'EOF'
export const WORKFLOW_TOOL_NAME = 'workflow'
EOF

# --- SnapshotUpdateDialog ---
mkdir -p src/components/agents
cat > src/components/agents/SnapshotUpdateDialog.tsx << 'EOF'
import React from 'react'
export function SnapshotUpdateDialog(props: any) { return null }
EOF

# --- AssistantSessionChooser ---
cat > src/assistant/AssistantSessionChooser.tsx << 'EOF'
import React from 'react'
export function AssistantSessionChooser(props: any) { return null }
EOF

# --- commands/assistant ---
mkdir -p src/commands/assistant
cat > src/commands/assistant/assistant.ts << 'EOF'
export default { name: 'assistant', description: 'Internal (stub)', isEnabled: () => false }
EOF

# --- commands/agents-platform ---
mkdir -p src/commands/agents-platform
cat > src/commands/agents-platform/index.ts << 'EOF'
export default { name: 'agents-platform', description: 'Internal (stub)', isEnabled: () => false }
EOF

# --- snipCompact ---
cat > src/services/compact/snipCompact.ts << 'EOF'
export function isSnipRuntimeEnabled(): boolean { return false }
export async function snipCompact() { return [] }
EOF

# --- cachedMicrocompact ---
cat > src/services/compact/cachedMicrocompact.ts << 'EOF'
export type CacheEditsBlock = { type: string }
export type CachedMCState = { cache: Map<string, unknown> }
export function createCachedMCState(): CachedMCState { return { cache: new Map() } }
export async function cachedMicrocompact() { return null }
EOF

# --- devtools (ink reconciler) ---
cat > src/ink/devtools.ts << 'EOF'
// React DevTools connector - stub
export {}
EOF

# --- global.d.ts ---
cat > src/global.d.ts << 'EOF'
declare const MACRO: {
  VERSION: string
  BUILD_TIME: string
  ISSUES_EXPLAINER: string
  FEEDBACK_CHANNEL: string
  PACKAGE_URL: string
  NATIVE_PACKAGE_URL: string
  VERSION_CHANGELOG: string
}
EOF

# --- SDK types ---
cat > src/entrypoints/sdk/coreTypes.generated.ts << 'EOF'
// Auto-generated core types - stub
export {}
EOF
mkdir -p src/entrypoints/sdk
cat > src/entrypoints/sdk/runtimeTypes.ts << 'EOF'
export type RuntimeConfig = Record<string, unknown>
export type SessionRunner = { run: () => Promise<void> }
EOF
cat > src/entrypoints/sdk/toolTypes.ts << 'EOF'
export type ToolDefinition = Record<string, unknown>
EOF

# --- filePersistence types ---
cat > src/utils/filePersistence/types.ts << 'EOF'
export const DEFAULT_UPLOAD_CONCURRENCY = 5
export const FILE_COUNT_LIMIT = 100
export const OUTPUTS_SUBDIR = 'outputs'
export type TurnStartTime = number
export type PersistedFile = { path: string; content: string; timestamp: number }
export type FailedPersistence = { path: string; error: string }
export type FilesPersistedEventData = { files: PersistedFile[]; failed: FailedPersistence[] }
export type FilePersistenceConfig = { enabled: boolean; maxFiles: number }
EOF

# --- verify skill markdown ---
mkdir -p src/skills/bundled/verify/examples
cat > src/skills/bundled/verify/SKILL.md << 'EOF'
# Verify Skill
Verification skill stub.
EOF
cat > src/skills/bundled/verify/examples/cli.md << 'EOF'
# CLI Verification Example
EOF
cat > src/skills/bundled/verify/examples/server.md << 'EOF'
# Server Verification Example
EOF

# --- External SDK packages (stubs) ---
NM=node_modules

mkdir -p "$NM/@anthropic-ai/bedrock-sdk"
cat > "$NM/@anthropic-ai/bedrock-sdk/package.json" << 'EOF'
{"name":"@anthropic-ai/bedrock-sdk","version":"1.0.0","type":"module","main":"index.js"}
EOF
cat > "$NM/@anthropic-ai/bedrock-sdk/index.js" << 'EOF'
export class AnthropicBedrock {
  constructor(config) { this.config = config }
}
EOF

mkdir -p "$NM/@anthropic-ai/foundry-sdk"
cat > "$NM/@anthropic-ai/foundry-sdk/package.json" << 'EOF'
{"name":"@anthropic-ai/foundry-sdk","version":"1.0.0","type":"module","main":"index.js"}
EOF
cat > "$NM/@anthropic-ai/foundry-sdk/index.js" << 'EOF'
export class AnthropicFoundry {
  constructor(config) { this.config = config }
}
EOF

mkdir -p "$NM/@anthropic-ai/vertex-sdk"
cat > "$NM/@anthropic-ai/vertex-sdk/package.json" << 'EOF'
{"name":"@anthropic-ai/vertex-sdk","version":"1.0.0","type":"module","main":"index.js"}
EOF
cat > "$NM/@anthropic-ai/vertex-sdk/index.js" << 'EOF'
export class AnthropicVertex {
  constructor(config) { this.config = config }
}
EOF

# --- global.d.ts for ink (Box.tsx / ScrollBox.tsx reference ../global.d.ts) ---
cp src/global.d.ts src/ink/global.d.ts

# --- ultraplan prompt ---
mkdir -p src/utils/ultraplan
echo "# Ultraplan prompt stub" > src/utils/ultraplan/prompt.txt

# --- contextCollapse ---
mkdir -p src/services/contextCollapse
cat > src/services/contextCollapse/index.ts << 'EOF'
export function isContextCollapseEnabled(): boolean { return false }
export function contextCollapse() { return null }
EOF

echo "All stubs created. Try 'bun run build' again."
