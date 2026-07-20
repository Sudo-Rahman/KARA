import { randomUUID } from "node:crypto";
import {
  mkdir,
  rename,
  unlink,
  writeFile,
} from "node:fs/promises";
import { join } from "node:path";

import {
  parseManifestBytes,
  verifyPublicationFiles,
} from "./contracts.js";
import {
  downloadBuffer,
  HttpStatusError,
} from "./network.js";
import {
  buildPublication,
  type Manifest,
  type Month,
} from "./publication.js";
import { parseEurostatCsv } from "./sources/eurostat.js";
import { parseImfWorkbook } from "./sources/imf.js";
import {
  classifyPublication,
  deriveCommonCoverage,
  evaluateFreshness,
  type Coverage,
} from "./update-policy.js";

export interface UpdateConfig {
  readonly outputDirectory: string;
  readonly archiveDirectory: string;
  readonly imfSourceUrl: string;
  readonly eurostatSourceUrl: string;
  readonly currentManifestUrl?: string;
  readonly publishedAt: string;
  readonly now: Date;
  readonly bootstrap: boolean;
}

export interface UpdateDependencies {
  readonly downloadSource?: (url: string) => Promise<Buffer>;
  readonly loadCurrentManifest?: (
    url: string,
  ) => Promise<Buffer | undefined>;
}

export type UpdateResult =
  | {
      readonly status: "changed";
      readonly changed: true;
      readonly generated: true;
      readonly coverage: Coverage;
      readonly dataVersion: string;
    }
  | {
      readonly status: "unchanged";
      readonly changed: false;
      readonly generated: true;
      readonly coverage: Coverage;
      readonly dataVersion: string;
    }
  | {
      readonly status: "waiting";
      readonly changed: false;
      readonly generated: true;
      readonly coverage: Coverage;
      readonly expectedThrough: Month;
    };

interface CurrentPublication {
  readonly manifest: Manifest;
  readonly manifestBytes: Buffer;
}

function hasHttpStatus(error: unknown, status: number): boolean {
  let candidate: unknown = error;
  const visited = new Set<unknown>();
  while (
    candidate instanceof Error &&
    !visited.has(candidate)
  ) {
    visited.add(candidate);
    if (
      candidate instanceof HttpStatusError &&
      candidate.status === status
    ) {
      return true;
    }
    candidate = candidate.cause;
  }
  return false;
}

async function defaultLoadCurrentManifest(
  url: string,
): Promise<Buffer | undefined> {
  try {
    return await downloadBuffer(url, { maxBytes: 1024 * 1024 });
  } catch (error) {
    if (hasHttpStatus(error, 404)) {
      return undefined;
    }
    throw error;
  }
}

async function archiveSources(
  directory: string,
  imfBytes: Buffer,
  eurostatBytes: Buffer,
): Promise<void> {
  await mkdir(directory, { recursive: true });
  await Promise.all([
    writeFile(join(directory, "imf-external-data.xlsx"), imfBytes),
    writeFile(join(directory, "eurostat-ert-bil-eur-m.csv"), eurostatBytes),
  ]);
}

async function writePublicationAtomically(
  outputDirectory: string,
  manifestBytes: Buffer,
  dataBytes: Buffer,
): Promise<void> {
  const directory = join(outputDirectory, "v1");
  await mkdir(directory, { recursive: true });

  const suffix = `.${process.pid}-${randomUUID()}.tmp`;
  const dataPath = join(directory, "metals-monthly.json");
  const manifestPath = join(directory, "manifest.json");
  const temporaryDataPath = `${dataPath}${suffix}`;
  const temporaryManifestPath = `${manifestPath}${suffix}`;

  try {
    await Promise.all([
      writeFile(temporaryDataPath, dataBytes, { flag: "wx" }),
      writeFile(temporaryManifestPath, manifestBytes, { flag: "wx" }),
    ]);
    await rename(temporaryDataPath, dataPath);
    await rename(temporaryManifestPath, manifestPath);
  } catch (error) {
    await Promise.allSettled([
      unlink(temporaryDataPath),
      unlink(temporaryManifestPath),
    ]);
    throw error;
  }
}

async function currentManifest(
  config: UpdateConfig,
  load: (url: string) => Promise<Buffer | undefined>,
): Promise<CurrentPublication | undefined> {
  if (config.currentManifestUrl === undefined) {
    return undefined;
  }

  const bytes = await load(config.currentManifestUrl);
  if (bytes === undefined) {
    if (!config.bootstrap) {
      throw new Error(
        "No current manifest exists; set BOOTSTRAP=true only for the first manual deployment",
      );
    }
    return undefined;
  }

  return {
    manifest: parseManifestBytes(bytes) as Manifest,
    manifestBytes: bytes,
  };
}

export async function runUpdate(
  config: UpdateConfig,
  dependencies: UpdateDependencies = {},
): Promise<UpdateResult> {
  const downloadSource =
    dependencies.downloadSource ??
    ((url: string) => downloadBuffer(url, { attempts: 3 }));
  const loadCurrentManifest =
    dependencies.loadCurrentManifest ?? defaultLoadCurrentManifest;

  const [imfBytes, eurostatBytes] = await Promise.all([
    downloadSource(config.imfSourceUrl),
    downloadSource(config.eurostatSourceUrl),
  ]);
  await archiveSources(
    config.archiveDirectory,
    imfBytes,
    eurostatBytes,
  );

  const [metalPricesUsd, euroEcuRates] = await Promise.all([
    parseImfWorkbook(imfBytes),
    Promise.resolve(parseEurostatCsv(eurostatBytes)),
  ]);
  const coverage = deriveCommonCoverage(
    metalPricesUsd,
    euroEcuRates,
    config.now,
  );
  const freshness = evaluateFreshness(coverage.through, config.now);
  const publication = buildPublication({
    ...coverage,
    publishedAt: config.publishedAt,
    metalPricesUsd,
    euroEcuRates,
  });
  verifyPublicationFiles(
    publication.manifestBytes,
    publication.dataBytes,
  );

  const current = await currentManifest(
    config,
    loadCurrentManifest,
  );
  const classification = classifyPublication(
    publication.manifest,
    current?.manifest,
  );

  const manifestBytes =
    classification === "unchanged" && current !== undefined
      ? current.manifestBytes
      : publication.manifestBytes;
  verifyPublicationFiles(manifestBytes, publication.dataBytes);

  if (freshness.status === "waiting") {
    await writePublicationAtomically(
      config.outputDirectory,
      manifestBytes,
      publication.dataBytes,
    );
    return {
      status: "waiting",
      changed: false,
      generated: true,
      coverage,
      expectedThrough: freshness.expectedThrough,
    };
  }

  if (classification === "unchanged") {
    await writePublicationAtomically(
      config.outputDirectory,
      manifestBytes,
      publication.dataBytes,
    );
    return {
      status: "unchanged",
      changed: false,
      generated: true,
      coverage,
      dataVersion: publication.manifest.dataVersion,
    };
  }

  await writePublicationAtomically(
    config.outputDirectory,
    publication.manifestBytes,
    publication.dataBytes,
  );
  return {
    status: "changed",
    changed: true,
    generated: true,
    coverage,
    dataVersion: publication.manifest.dataVersion,
  };
}
