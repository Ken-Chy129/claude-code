export type CacheEditsBlock = { type: string }
export type CachedMCState = { cache: Map<string, unknown> }
export function createCachedMCState(): CachedMCState { return { cache: new Map() } }
export async function cachedMicrocompact() { return null }
