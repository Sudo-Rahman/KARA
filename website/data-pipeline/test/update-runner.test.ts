import {
  access,
  mkdtemp,
  readFile,
  rm,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { afterEach, describe, expect, test } from "vitest";

import { verifyPublicationFiles } from "../src/contracts.js";
import { buildPublication } from "../src/publication.js";
import {
  runUpdate,
  type UpdateConfig,
  type UpdateDependencies,
} from "../src/update-runner.js";

const temporaryDirectories: string[] = [];

async function temporaryDirectory(): Promise<string> {
  const directory = await mkdtemp(join(tmpdir(), "kara-metals-test-"));
  temporaryDirectories.push(directory);
  return directory;
}

afterEach(async () => {
  await Promise.all(
    temporaryDirectories.splice(0).map((directory) =>
      rm(directory, { recursive: true, force: true }),
    ),
  );
});

async function sourceDependencies(
  currentManifest?: Buffer,
  invalidImf = false,
): Promise<UpdateDependencies> {
  const encoded = await readFile(
    new URL("./fixtures/imf-monthly.xlsx.base64", import.meta.url),
    "utf8",
  );
  const imf = invalidImf
    ? Buffer.from("invalid workbook")
    : Buffer.from(encoded.trim(), "base64");
  const eurostat = await readFile(
    new URL("./fixtures/eurostat-monthly.csv", import.meta.url),
  );

  return {
    downloadSource: async (url) =>
      url.includes("imf") ? imf : eurostat,
    loadCurrentManifest: async () => currentManifest,
  };
}

function config(root: string, overrides: Partial<UpdateConfig> = {}): UpdateConfig {
  return {
    outputDirectory: join(root, "public"),
    archiveDirectory: join(root, "sources"),
    imfSourceUrl: "https://example.test/imf.xlsx",
    eurostatSourceUrl: "https://example.test/eurostat.csv",
    publishedAt: "1987-03-11T05:17:00.000Z",
    now: new Date("1987-03-11T05:17:00.000Z"),
    bootstrap: false,
    ...overrides,
  };
}

async function exists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

describe("end-to-end update runner", () => {
  test("archives sources and atomically writes a verified publication", async () => {
    const root = await temporaryDirectory();
    const result = await runUpdate(
      config(root),
      await sourceDependencies(),
    );

    expect(result).toMatchObject({
      status: "changed",
      changed: true,
      coverage: { from: "1987-01", through: "1987-02" },
    });

    const manifest = await readFile(
      join(root, "public/v1/manifest.json"),
    );
    const snapshot = await readFile(
      join(root, "public/v1/metals-monthly.json"),
    );
    expect(() => verifyPublicationFiles(manifest, snapshot)).not.toThrow();
    expect(await exists(join(root, "sources/imf-external-data.xlsx"))).toBe(
      true,
    );
    expect(
      await exists(join(root, "sources/eurostat-ert-bil-eur-m.csv")),
    ).toBe(true);
  });

  test("archives a candidate without deployment when the source is one month behind", async () => {
    const root = await temporaryDirectory();
    const result = await runUpdate(
      config(root, {
        now: new Date("1987-04-11T05:17:00.000Z"),
        publishedAt: "1987-04-11T05:17:00.000Z",
      }),
      await sourceDependencies(),
    );

    expect(result).toEqual({
      status: "waiting",
      changed: false,
      generated: true,
      coverage: { from: "1987-01", through: "1987-02" },
      expectedThrough: "1987-03",
    });
    expect(await exists(join(root, "public/v1/manifest.json"))).toBe(true);
  });

  test("leaves publication files untouched when an input is malformed", async () => {
    const root = await temporaryDirectory();
    const output = join(root, "public/v1");
    await expect(
      runUpdate(
        config(root),
        await sourceDependencies(undefined, true),
      ),
    ).rejects.toThrow("Invalid IMF workbook");

    expect(await exists(join(output, "manifest.json"))).toBe(false);
    expect(await exists(join(output, "metals-monthly.json"))).toBe(false);
  });

  test("preserves the published manifest and does not mark an unchanged SHA-256 for deployment", async () => {
    const firstRoot = await temporaryDirectory();
    await runUpdate(config(firstRoot), await sourceDependencies());
    const currentManifest = await readFile(
      join(firstRoot, "public/v1/manifest.json"),
    );

    const secondRoot = await temporaryDirectory();
    const result = await runUpdate(
      config(secondRoot, {
        currentManifestUrl: "https://example.test/v1/manifest.json",
        publishedAt: "1987-03-12T05:17:00.000Z",
      }),
      await sourceDependencies(currentManifest),
    );

    expect(result.status).toBe("unchanged");
    expect(result.changed).toBe(false);
    expect(
      await exists(join(secondRoot, "public/v1/manifest.json")),
    ).toBe(true);
    expect(
      (
        await readFile(
          join(secondRoot, "public/v1/manifest.json"),
        )
      ).equals(currentManifest),
    ).toBe(true);
  });

  test("rejects a regressive candidate without touching output files", async () => {
    const current = buildPublication({
      from: "1987-01",
      through: "1987-03",
      publishedAt: "1987-04-01T05:17:00.000Z",
      metalPricesUsd: {
        XAU: { "1987-01": "10", "1987-02": "11", "1987-03": "12" },
        XAG: { "1987-01": "10", "1987-02": "11", "1987-03": "12" },
        XPT: { "1987-01": "10", "1987-02": "11", "1987-03": "12" },
        XPD: { "1987-01": "10", "1987-02": "11", "1987-03": "12" },
      },
      euroEcuRates: {
        "1987-01": { USD: "1.1", CHF: "1.6", GBP: "0.7" },
        "1987-02": { USD: "1.1", CHF: "1.6", GBP: "0.7" },
        "1987-03": { USD: "1.1", CHF: "1.6", GBP: "0.7" },
      },
    });
    const root = await temporaryDirectory();

    await expect(
      runUpdate(
        config(root, {
          currentManifestUrl:
            "https://example.test/v1/manifest.json",
          now: new Date("1987-04-11T05:17:00.000Z"),
          publishedAt: "1987-04-11T05:17:00.000Z",
        }),
        await sourceDependencies(current.manifestBytes),
      ),
    ).rejects.toThrow("Coverage regression");

    expect(await exists(join(root, "public/v1/manifest.json"))).toBe(false);
    expect(
      await exists(join(root, "public/v1/metals-monthly.json")),
    ).toBe(false);
  });

  test("keeps waiting after the 12th when the source is one month behind", async () => {
    const root = await temporaryDirectory();

    const result = await runUpdate(
      config(root, {
        now: new Date("1987-04-20T05:17:00.000Z"),
        publishedAt: "1987-04-20T05:17:00.000Z",
      }),
      await sourceDependencies(),
    );

    expect(result).toMatchObject({ status: "waiting", changed: false });
    expect(await exists(join(root, "public/v1/manifest.json"))).toBe(true);
  });

  test("requires an explicit bootstrap when the public manifest is absent", async () => {
    const root = await temporaryDirectory();
    const updateConfig = config(root, {
      currentManifestUrl:
        "https://example.test/v1/manifest.json",
    });

    await expect(
      runUpdate(updateConfig, await sourceDependencies()),
    ).rejects.toThrow("set BOOTSTRAP=true");
    expect(await exists(join(root, "public/v1/manifest.json"))).toBe(false);

    const result = await runUpdate(
      { ...updateConfig, bootstrap: true },
      await sourceDependencies(),
    );
    expect(result.status).toBe("changed");
    expect(await exists(join(root, "public/v1/manifest.json"))).toBe(true);
  });
});
