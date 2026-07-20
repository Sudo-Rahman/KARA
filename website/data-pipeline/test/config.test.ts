import { describe, expect, test } from "vitest";

import { configFromEnvironment } from "../src/config.js";

describe("CLI configuration", () => {
  test("uses deterministic test clock and resolves default directories", () => {
    expect(
      configFromEnvironment(
        { NOW: "2026-06-11T05:17:00.000Z" },
        "/workspace/website/data-pipeline",
      ),
    ).toMatchObject({
      outputDirectory: "/workspace/website/data-pipeline/public",
      archiveDirectory: "/workspace/website/data-pipeline/artifacts/sources",
      publishedAt: "2026-06-11T05:17:00.000Z",
      now: new Date("2026-06-11T05:17:00.000Z"),
      bootstrap: false,
    });
  });

  test("accepts explicit source and publication settings", () => {
    const value = configFromEnvironment(
      {
        NOW: "2026-06-11T05:17:00.000Z",
        PUBLISHED_AT: "2026-06-11T06:00:00.000Z",
        OUTPUT_DIR: "work/public",
        SOURCE_ARCHIVE_DIR: "work/sources",
        IMF_SOURCE_URL: "https://example.test/imf.xlsx",
        EUROSTAT_SOURCE_URL: "https://example.test/eurostat.csv",
        CURRENT_MANIFEST_URL: "https://data.example.test/v1/manifest.json",
        BOOTSTRAP: "true",
      },
      "/workspace/website/data-pipeline",
    );

    expect(value).toMatchObject({
      outputDirectory: "/workspace/website/data-pipeline/work/public",
      archiveDirectory: "/workspace/website/data-pipeline/work/sources",
      currentManifestUrl:
        "https://data.example.test/v1/manifest.json",
      bootstrap: true,
    });
  });

  test("rejects an invalid clock", () => {
    expect(() =>
      configFromEnvironment(
        { NOW: "not-a-date" },
        "/workspace/website/data-pipeline",
      ),
    ).toThrow("NOW must be a valid ISO-8601 date");
  });
});
