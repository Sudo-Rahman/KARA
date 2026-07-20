import { describe, expect, test, vi } from "vitest";

import { downloadBuffer } from "../src/network.js";

describe("source downloader", () => {
  test("makes exactly three attempts when the network is unavailable", async () => {
    const fetchImpl = vi.fn(async () => {
      throw new TypeError("network unavailable");
    });

    await expect(
      downloadBuffer("https://example.test/source", {
        fetchImpl,
        attempts: 3,
        wait: async () => undefined,
      }),
    ).rejects.toThrow("after 3 attempts");

    expect(fetchImpl).toHaveBeenCalledTimes(3);
  });

  test("retries a server error and returns the successful bytes", async () => {
    const fetchImpl = vi
      .fn()
      .mockResolvedValueOnce(new Response("retry", { status: 503 }))
      .mockResolvedValueOnce(new Response("source bytes", { status: 200 }));

    const result = await downloadBuffer("https://example.test/source", {
      fetchImpl,
      attempts: 3,
      wait: async () => undefined,
    });

    expect(result.toString("utf8")).toBe("source bytes");
    expect(fetchImpl).toHaveBeenCalledTimes(2);
  });

  test("rejects a response larger than the configured limit", async () => {
    const fetchImpl = vi.fn(
      async () => new Response("123456", { status: 200 }),
    );

    await expect(
      downloadBuffer("https://example.test/source", {
        fetchImpl,
        maxBytes: 5,
      }),
    ).rejects.toThrow("exceeds 5 bytes");
  });
});
