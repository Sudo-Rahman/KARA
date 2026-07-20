import { describe, expect, test } from "vitest";

import type { Manifest, MetalCode } from "../src/publication.js";
import {
  classifyPublication,
  deriveCommonCoverage,
  evaluateFreshness,
} from "../src/update-policy.js";

const METALS: readonly MetalCode[] = ["XAU", "XAG", "XPT", "XPD"];

function prices(months: readonly string[]) {
  return Object.fromEntries(
    METALS.map((metal) => [
      metal,
      Object.fromEntries(months.map((month) => [month, "10"])),
    ]),
  ) as Record<MetalCode, Record<string, string>>;
}

function rates(months: readonly string[]) {
  return Object.fromEntries(
    months.map((month) => [
      month,
      { USD: "1.1", CHF: "1.6", GBP: "0.7" },
    ]),
  );
}

function manifest(
  from: `${number}-${string}`,
  through: `${number}-${string}`,
  dataVersion: string,
): Manifest {
  return {
    schemaVersion: 1,
    datasetId: "precious-metals-monthly",
    dataVersion,
    publishedAt: "2026-07-20T10:00:00.000Z",
    metals: ["XAU", "XAG", "XPT", "XPD"],
    coverage: { from, through },
    currencies: {
      USD: { from, through },
      CHF: { from, through },
      GBP: { from, through },
      ...(from < "1999-01"
        ? {
            XEU: {
              from,
              through: through < "1999-01" ? through : "1998-12",
            },
          }
        : {}),
      ...(through >= "1999-01"
        ? { EUR: { from: from < "1999-01" ? "1999-01" : from, through } }
        : {}),
    },
    file: {
      url: "/v1/metals-monthly.json",
      sha256: dataVersion,
      bytes: 100,
    },
  };
}

describe("coverage policy", () => {
  test("uses the complete continuous intersection and excludes the current month", () => {
    const months = ["1987-01", "1987-02", "1987-03", "1987-04"];

    expect(
      deriveCommonCoverage(
        prices(months),
        rates(months),
        new Date("1987-04-20T10:00:00.000Z"),
      ),
    ).toEqual({ from: "1987-01", through: "1987-03" });
  });

  test("rejects a hole inside a source series", () => {
    const metalPrices = prices(["1987-01", "1987-02", "1987-03"]);
    delete metalPrices.XPD["1987-02"];

    expect(() =>
      deriveCommonCoverage(
        metalPrices,
        rates(["1987-01", "1987-02", "1987-03"]),
        new Date("1987-04-20T10:00:00.000Z"),
      ),
    ).toThrow("Missing XPD price for 1987-02");
  });

  test("waits without failing when the source is one month behind", () => {
    expect(
      evaluateFreshness(
        "2026-05",
        new Date("2026-07-11T05:17:00.000Z"),
      ),
    ).toEqual({
      status: "waiting",
      expectedThrough: "2026-06",
      actualThrough: "2026-05",
    });

    expect(
      evaluateFreshness(
        "2026-05",
        new Date("2026-07-20T05:17:00.000Z"),
      ),
    ).toEqual({
      status: "waiting",
      expectedThrough: "2026-06",
      actualThrough: "2026-05",
    });
  });

  test("never grants the grace period when more than the newest month is absent", () => {
    expect(() =>
      evaluateFreshness(
        "2026-04",
        new Date("2026-07-05T05:17:00.000Z"),
      ),
    ).toThrow("Source coverage is more than one month behind");
  });
});

describe("publication classification", () => {
  test("does not redeploy an unchanged SHA-256", () => {
    expect(
      classifyPublication(
        manifest("1987-01", "2026-06", "a".repeat(64)),
        manifest("1987-01", "2026-06", "a".repeat(64)),
      ),
    ).toBe("unchanged");
  });

  test("rejects a coverage regression before considering a new hash", () => {
    expect(() =>
      classifyPublication(
        manifest("1987-01", "2026-05", "b".repeat(64)),
        manifest("1987-01", "2026-06", "a".repeat(64)),
      ),
    ).toThrow("Coverage regression");
  });

  test("accepts a changed snapshot whose coverage is not shorter", () => {
    expect(
      classifyPublication(
        manifest("1987-01", "2026-07", "b".repeat(64)),
        manifest("1987-01", "2026-06", "a".repeat(64)),
      ),
    ).toBe("changed");
  });
});
