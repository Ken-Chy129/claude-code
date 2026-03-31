export type RuntimeConfig = Record<string, unknown>
export type SessionRunner = { run: () => Promise<void> }
