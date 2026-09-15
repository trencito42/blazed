/**
 * MCP tool result helpers — every tool returns structured JSON text so the
 * model never has to infer success from prose.
 */
import { toStructuredError } from './client.js';

export function ok(result: unknown): { content: Array<{ type: 'text'; text: string }> } {
  return {
    content: [{ type: 'text', text: JSON.stringify({ ok: true, result }, null, 2) }],
  };
}

export function fail(e: unknown): { content: Array<{ type: 'text'; text: string }>; isError: true } {
  const err = toStructuredError(e);
  return {
    isError: true,
    content: [{ type: 'text', text: JSON.stringify({ ok: false, error: err }, null, 2) }],
  };
}

export function imageResult(text: string, imageData: string, mimeType: string) {
  return {
    content: [
      { type: 'text' as const, text },
      { type: 'image' as const, data: imageData, mimeType },
    ],
  };
}

/** Deep-equal for assertion comparisons (JSON-safe values only). */
export function deepEqual(a: unknown, b: unknown): boolean {
  return JSON.stringify(a) === JSON.stringify(b);
}

export function assertionResult(passed: boolean, expected: unknown, actual: unknown, label: string) {
  return {
    passed,
    assertion: label,
    expected,
    actual,
  };
}
