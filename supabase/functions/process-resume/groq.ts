/**
 * Shared pipeline stages + Groq config.
 * Ported from backend/app/services/groq_api_service.rb
 */

export type Stage = 'reader' | 'polisher' | 'latex';

export interface StageConfig {
  keyEnvNames: string[];
  defaultModels: string[];
  jsonMode: boolean;
  maxTokens: number;
  temperature: number;
}

export const STAGE_CONFIGS: Record<Stage, StageConfig> = {
  reader: {
    keyEnvNames: [
      'GROQ_API_KEY_READER',
      'GROQ_API_KEY_READER_2',
      'GROQ_API_KEY_READER_3',
      'GROQ_API_KEY_READER_4',
    ],
    // JSON mode required for extraction.
    defaultModels: ['qwen/qwen3.8-27b'],
    jsonMode: true,
    maxTokens: 4000,
    temperature: 0.1,
  },
  polisher: {
    keyEnvNames: [
      'GROQ_API_KEY_POLISHER',
      'GROQ_API_KEY_POLISHER_2',
      'GROQ_API_KEY_POLISHER_3',
    ],
    defaultModels: ['qwen/qwen3.8-27b'],
    jsonMode: true,
    // Richer output: 3-4 expanded bullets per role + synthesized summary.
    maxTokens: 7000,
    temperature: 0.3,
  },
  latex: {
    keyEnvNames: [
      'GROQ_API_KEY_LATEX',
      'GROQ_API_KEY_LATEX_2',
      'GROQ_API_KEY_LATEX_3',
    ],
    defaultModels: ['openai/gpt-oss-120b', 'qwen/qwen3.8-27b'],
    jsonMode: false,
    // Full-page LaTeX with 3-4 bullets per role needs more room.
    maxTokens: 6000,
    temperature: 0.2,
  },
};

export const RETRYABLE_STATUSES = [429, 500, 502, 503, 504];
export const KEY_ROTATE_STATUSES = [401, 403, 429];

export function resolveApiKeys(stage: Stage): string[] {
  const config = STAGE_CONFIGS[stage];
  const keys = config.keyEnvNames
    .map((name) => Deno.env.get(name))
    .filter((k): k is string => Boolean(k && k.trim()));

  if (keys.length > 0) return keys;

  const single = Deno.env.get('GROQ_API_KEY');
  if (single && single.trim()) return [single.trim()];

  throw new Error(
    `No API keys found for Groq ${stage} stage. Set GROQ_API_KEY_${stage.toUpperCase()} or GROQ_API_KEY`
  );
}

export function resolveModels(stage: Stage): string[] {
  const configured = Deno.env.get(`GROQ_MODEL_${stage.toUpperCase()}`);
  if (configured && configured.trim()) {
    return [configured.trim(), ...STAGE_CONFIGS[stage].defaultModels];
  }
  return STAGE_CONFIGS[stage].defaultModels;
}

export function extractErrorMessage(body: unknown): string {
  if (body && typeof body === 'object' && 'error' in body) {
    const err = (body as { error?: { message?: string } }).error;
    if (err?.message) return err.message;
  }
  return JSON.stringify(body).slice(0, 500);
}

export function isKeyRotationError(status: number, message: string): boolean {
  if (KEY_ROTATE_STATUSES.includes(status)) return true;
  return /api key|quota|rate limit|billing|exceeded|insufficient|invalid key/i.test(message);
}

export function isRetryableError(status: number, message: string): boolean {
  if (RETRYABLE_STATUSES.includes(status)) return true;
  return /high demand|overloaded|temporar|try again|unavailable/i.test(message);
}

export function friendlyError(stage: Stage, status: number, message: string): string {
  switch (status) {
    case 401:
      return `Groq ${stage}: Invalid API key — check your GROQ_API_KEY_${stage.toUpperCase()}`;
    case 429:
      return `Groq ${stage}: Rate limit exceeded — try again shortly`;
    case 400:
      return `Groq ${stage}: Bad request — ${message}`;
    default:
      return `Groq ${stage} API error: ${message}`;
  }
}

export function cleanOutput(text: string): string {
  return text
    .trim()
    .replace(/^```(?:json|latex|tex)?\s*/i, '')
    .replace(/```\s*$/, '')
    .trim();
}
