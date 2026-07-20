import { setTimeout as waitFor } from "node:timers/promises";

export type FetchLike = (
  input: string,
  init?: RequestInit,
) => Promise<Response>;

export interface DownloadOptions {
  readonly attempts?: number;
  readonly fetchImpl?: FetchLike;
  readonly maxBytes?: number;
  readonly timeoutMs?: number;
  readonly wait?: (milliseconds: number) => Promise<unknown>;
}

export class HttpStatusError extends Error {
  constructor(
    readonly status: number,
    readonly url: string,
  ) {
    super(`HTTP ${status} while downloading ${url}`);
    this.name = "HttpStatusError";
  }
}

class SizeLimitError extends Error {}

async function responseBytes(
  response: Response,
  maxBytes: number,
  url: string,
): Promise<Buffer> {
  const contentLength = response.headers.get("content-length");
  if (
    contentLength !== null &&
    Number.isFinite(Number(contentLength)) &&
    Number(contentLength) > maxBytes
  ) {
    throw new SizeLimitError(
      `Download from ${url} exceeds ${maxBytes} bytes`,
    );
  }

  if (response.body === null) {
    return Buffer.alloc(0);
  }

  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      total += value.byteLength;
      if (total > maxBytes) {
        await reader.cancel();
        throw new SizeLimitError(
          `Download from ${url} exceeds ${maxBytes} bytes`,
        );
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  return Buffer.concat(chunks.map((chunk) => Buffer.from(chunk)), total);
}

function retryable(error: unknown): boolean {
  if (error instanceof SizeLimitError) {
    return false;
  }
  if (error instanceof HttpStatusError) {
    return (
      error.status === 408 ||
      error.status === 425 ||
      error.status === 429 ||
      error.status >= 500
    );
  }
  return true;
}

export async function downloadBuffer(
  url: string,
  options: DownloadOptions = {},
): Promise<Buffer> {
  const attempts = options.attempts ?? 3;
  const fetchImpl = options.fetchImpl ?? fetch;
  const maxBytes = options.maxBytes ?? 25 * 1024 * 1024;
  const timeoutMs = options.timeoutMs ?? 30_000;
  const wait = options.wait ?? ((milliseconds) => waitFor(milliseconds));

  if (!Number.isInteger(attempts) || attempts < 1) {
    throw new Error("Download attempts must be a positive integer");
  }
  if (!Number.isInteger(maxBytes) || maxBytes < 1) {
    throw new Error("Download maxBytes must be a positive integer");
  }

  let lastError: unknown;
  let attempted = 0;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    attempted = attempt;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetchImpl(url, {
        headers: {
          Accept: "application/octet-stream, text/csv;q=0.9, */*;q=0.1",
          "User-Agent": "kara-metals-data/1.0",
        },
        redirect: "follow",
        signal: controller.signal,
      });
      if (!response.ok) {
        throw new HttpStatusError(response.status, url);
      }
      return await responseBytes(response, maxBytes, url);
    } catch (error) {
      lastError = error;
      if (!retryable(error) || attempt === attempts) {
        break;
      }
      await wait(500 * 2 ** (attempt - 1));
    } finally {
      clearTimeout(timeout);
    }
  }

  const detail =
    lastError instanceof Error ? lastError.message : String(lastError);
  throw new Error(
    `Failed to download ${url} after ${attempted} attempt${attempted === 1 ? "" : "s"}: ${detail}`,
    { cause: lastError },
  );
}
