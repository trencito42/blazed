/**
 * Bridge client: HTTP JSON to the FXServer test agent.
 *
 * Protocol choice (documented per requirements):
 *  - HTTP POST JSON on the FXServer game port (SetHttpHandler). No extra
 *    ports, no firewall changes, works over SSH tunnels.
 *  - Request/response correlation via requestId in the JSON body.
 *  - Bearer token auth (env: FIVEM_TEST_TOKEN), never hardcoded.
 *  - Timeouts per call (env: FIVEM_TEST_TIMEOUT_MS, default 20000).
 *  - Structured errors: { code, message, retryable } pass through verbatim.
 */

export interface BridgeError {
  code: string;
  message: string;
  retryable: boolean;
}

export interface BridgeResponse<T = unknown> {
  ok: true;
  requestId: string;
  result: T;
}

export class TestAgentClient {
  private readonly baseUrl: string;
  private readonly token: string;
  private readonly timeoutMs: number;
  private counter = 0;

  constructor() {
    const host = process.env.FIVEM_TEST_HOST ?? '127.0.0.1';
    const port = process.env.FIVEM_TEST_PORT ?? '30120';
    this.baseUrl = process.env.FIVEM_TEST_URL ?? `http://${host}:${port}/testagent`;
    this.token = process.env.FIVEM_TEST_TOKEN ?? '';
    this.timeoutMs = Number(process.env.FIVEM_TEST_TIMEOUT_MS ?? 20000);
  }

  get isConfigured(): boolean {
    return this.token.length > 0;
  }

  private nextRequestId(): string {
    this.counter += 1;
    return `mcp_${Date.now()}_${this.counter}`;
  }

  /** Invoke a test-agent tool. Throws BridgeCallError on transport/tool errors. */
  async call<T = unknown>(tool: string, args: Record<string, unknown> = {}): Promise<T> {
    if (!this.isConfigured) {
      throw new BridgeCallError({
        code: 'UNAUTHORIZED',
        message: 'FIVEM_TEST_TOKEN is not set in the MCP server environment. Configure it and restart the MCP server.',
        retryable: false,
      });
    }
    const requestId = this.nextRequestId();
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    let res: Response;
    try {
      res = await fetch(`${this.baseUrl}/invoke`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.token}`,
        },
        body: JSON.stringify({ requestId, tool, ...args }),
        signal: controller.signal,
      });
    } catch (e) {
      clearTimeout(timer);
      const aborted = e instanceof Error && e.name === 'AbortError';
      throw new BridgeCallError(
        aborted
          ? { code: 'TIMEOUT', message: `bridge call ${tool} timed out after ${this.timeoutMs}ms`, retryable: true }
          : {
              code: 'BRIDGE_UNREACHABLE',
              message: `cannot reach the test agent at ${this.baseUrl} — is FXServer running with sunset_test_agent enabled? (${String(e)})`,
              retryable: true,
            },
      );
    }
    clearTimeout(timer);

    const text = await res.text();
    let body: Record<string, unknown>;
    try {
      body = JSON.parse(text) as Record<string, unknown>;
    } catch {
      throw new BridgeCallError({
        code: 'BAD_RESPONSE',
        message: `non-JSON response (HTTP ${res.status}): ${text.slice(0, 300)}`,
        retryable: false,
      });
    }

    if (res.status === 401 || res.status === 403) {
      const err = body.error as Partial<BridgeError> | undefined;
      throw new BridgeCallError({
        code: err?.code ?? 'UNAUTHORIZED',
        message: err?.message ?? `HTTP ${res.status} from the test agent (token/kill switch)`,
        retryable: false,
      });
    }

    if (body.ok === true) {
      return body.result as T;
    }
    const err = body.error as Partial<BridgeError> | undefined;
    throw new BridgeCallError({
      code: err?.code ?? 'INTERNAL',
      message: err?.message ?? 'unknown bridge error',
      retryable: err?.retryable === true,
    });
  }

  /** Download a stored screenshot (raw bytes + mime). */
  async screenshot(requestId: string): Promise<{ bytes: Buffer; mime: string }> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const res = await fetch(`${this.baseUrl}/screenshot/${encodeURIComponent(requestId)}`, {
        headers: { Authorization: `Bearer ${this.token}` },
        signal: controller.signal,
      });
      if (!res.ok) {
        throw new BridgeCallError({
          code: 'SCREENSHOT_FAILED',
          message: `screenshot download failed HTTP ${res.status}`,
          retryable: true,
        });
      }
      const mime = res.headers.get('content-type') ?? 'image/jpeg';
      const buf = Buffer.from(await res.arrayBuffer());
      return { bytes: buf, mime };
    } finally {
      clearTimeout(timer);
    }
  }
}

export class BridgeCallError extends Error {
  readonly code: string;
  readonly retryable: boolean;

  constructor(err: BridgeError) {
    super(err.message);
    this.name = 'BridgeCallError';
    this.code = err.code;
    this.retryable = err.retryable;
  }
}

/** Normalize any thrown error into the structured error contract. */
export function toStructuredError(e: unknown): BridgeError {
  if (e instanceof BridgeCallError) {
    return { code: e.code, message: e.message, retryable: e.retryable };
  }
  return {
    code: 'INTERNAL',
    message: e instanceof Error ? e.message : String(e),
    retryable: false,
  };
}
