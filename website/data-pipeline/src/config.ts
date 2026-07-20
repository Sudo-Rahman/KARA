import { resolve } from "node:path";

import type { UpdateConfig } from "./update-runner.js";

export const DEFAULT_IMF_SOURCE_URL =
  "https://www.imf.org/-/media/files/research/commodityprices/monthly/external-data.xlsx";
export const DEFAULT_EUROSTAT_SOURCE_URL =
  "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/ert_bil_eur_m/M.AVG.NAC.CHF+GBP+USD?startPeriod=1980-01&format=SDMX-CSV";

type Environment = Readonly<Record<string, string | undefined>>;

function dateFrom(
  name: string,
  value: string | undefined,
  fallback?: Date,
): Date {
  if (value === undefined || value.trim() === "") {
    if (fallback !== undefined) {
      return fallback;
    }
    throw new Error(`${name} is required`);
  }

  const parsed = new Date(value);
  if (!Number.isFinite(parsed.getTime())) {
    throw new Error(`${name} must be a valid ISO-8601 date`);
  }
  return parsed;
}

function urlFrom(name: string, value: string): string {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error(`${name} must be an absolute URL`);
  }
  if (url.protocol !== "https:" && url.protocol !== "http:") {
    throw new Error(`${name} must use HTTP or HTTPS`);
  }
  return url.toString();
}

function optionalUrl(
  name: string,
  value: string | undefined,
): string | undefined {
  if (value === undefined || value.trim() === "") {
    return undefined;
  }
  return urlFrom(name, value);
}

function booleanFrom(
  name: string,
  value: string | undefined,
): boolean {
  if (value === undefined || value === "" || value === "false") {
    return false;
  }
  if (value === "true") {
    return true;
  }
  throw new Error(`${name} must be "true" or "false"`);
}

export function configFromEnvironment(
  environment: Environment = process.env,
  workingDirectory = process.cwd(),
): UpdateConfig {
  const now = dateFrom("NOW", environment.NOW, new Date());
  const publishedAt = dateFrom(
    "PUBLISHED_AT",
    environment.PUBLISHED_AT,
    now,
  ).toISOString();

  return {
    outputDirectory: resolve(
      workingDirectory,
      environment.OUTPUT_DIR ?? "public",
    ),
    archiveDirectory: resolve(
      workingDirectory,
      environment.SOURCE_ARCHIVE_DIR ?? "artifacts/sources",
    ),
    imfSourceUrl: urlFrom(
      "IMF_SOURCE_URL",
      environment.IMF_SOURCE_URL ?? DEFAULT_IMF_SOURCE_URL,
    ),
    eurostatSourceUrl: urlFrom(
      "EUROSTAT_SOURCE_URL",
      environment.EUROSTAT_SOURCE_URL ??
        DEFAULT_EUROSTAT_SOURCE_URL,
    ),
    currentManifestUrl: optionalUrl(
      "CURRENT_MANIFEST_URL",
      environment.CURRENT_MANIFEST_URL,
    ),
    publishedAt,
    now,
    bootstrap: booleanFrom("BOOTSTRAP", environment.BOOTSTRAP),
  };
}
