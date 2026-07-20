import { createHash } from "node:crypto";
import { describe, expect, test } from "vitest";

import { buildPublication } from "../src/publication.js";

describe("monthly metals publication", () => {
  test("publishes pre-calculated prices and a manifest bound to the data bytes", () => {
    const publication = buildPublication({
      from: "1999-01",
      through: "1999-01",
      publishedAt: "2026-07-20T10:00:00.000Z",
      metalPricesUsd: {
        XAU: { "1999-01": "500" },
        XAG: { "1999-01": "10" },
        XPT: { "1999-01": "600" },
        XPD: { "1999-01": "300" },
      },
      euroEcuRates: {
        "1999-01": {
          USD: "1.2",
          CHF: "1.8",
          GBP: "0.8",
        },
      },
    });

    expect(publication.snapshot.series[0]).toEqual({
      metal: "XAU",
      observations: [
        {
          month: "1999-01",
          prices: {
            USD: "500.000000",
            EUR: "416.666667",
            CHF: "750.000000",
            GBP: "333.333333",
          },
        },
      ],
    });

    expect(publication.snapshot.sources).toEqual([
      {
        id: "imf-pcps",
        role: "metal_prices_usd",
        title: "IMF Primary Commodity Prices",
        url: "https://www.imf.org/en/research/commodity-prices",
        attribution:
          "Source: International Monetary Fund, Primary Commodity Prices; transformed by Kara.",
        termsUrl: "https://www.imf.org/en/about/copyright-and-terms",
      },
      {
        id: "eurostat-ert-bil-eur-m",
        role: "exchange_rates",
        title: "Euro/ECU exchange rates - monthly data",
        url: "https://ec.europa.eu/eurostat/databrowser/view/ert_bil_eur_m/default/table",
        attribution: "Source: Eurostat, ert_bil_eur_m; transformed by Kara.",
        termsUrl: "https://ec.europa.eu/eurostat/help/copyright-notice",
      },
    ]);

    const expectedHash = createHash("sha256")
      .update(publication.dataBytes)
      .digest("hex");

    expect(publication.manifest).toMatchObject({
      schemaVersion: 1,
      datasetId: "precious-metals-monthly",
      dataVersion: expectedHash,
      publishedAt: "2026-07-20T10:00:00.000Z",
      metals: ["XAU", "XAG", "XPT", "XPD"],
      coverage: { from: "1999-01", through: "1999-01" },
      file: {
        url: "/v1/metals-monthly.json",
        sha256: expectedHash,
        bytes: publication.dataBytes.byteLength,
      },
    });
  });

  test("rejects an incomplete metal month instead of publishing an artificial zero", () => {
    expect(() =>
      buildPublication({
        from: "1999-01",
        through: "1999-01",
        publishedAt: "2026-07-20T10:00:00.000Z",
        metalPricesUsd: {
          XAU: { "1999-01": "500" },
          XAG: { "1999-01": "10" },
          XPT: { "1999-01": "600" },
          XPD: {},
        },
        euroEcuRates: {
          "1999-01": { USD: "1.2", CHF: "1.8", GBP: "0.8" },
        },
      }),
    ).toThrowError("Missing XPD price for 1999-01");
  });

  test("rejects a missing exchange-rate month inside the requested coverage", () => {
    const prices = {
      "1999-01": "10",
      "1999-02": "11",
      "1999-03": "12",
    };

    expect(() =>
      buildPublication({
        from: "1999-01",
        through: "1999-03",
        publishedAt: "2026-07-20T10:00:00.000Z",
        metalPricesUsd: {
          XAU: prices,
          XAG: prices,
          XPT: prices,
          XPD: prices,
        },
        euroEcuRates: {
          "1999-01": { USD: "1.2", CHF: "1.8", GBP: "0.8" },
          "1999-03": { USD: "1.3", CHF: "1.9", GBP: "0.9" },
        },
      }),
    ).toThrowError("Missing exchange rates for 1999-02");
  });

  test("rejects non-positive market values", () => {
    expect(() =>
      buildPublication({
        from: "1999-01",
        through: "1999-01",
        publishedAt: "2026-07-20T10:00:00.000Z",
        metalPricesUsd: {
          XAU: { "1999-01": "0" },
          XAG: { "1999-01": "10" },
          XPT: { "1999-01": "600" },
          XPD: { "1999-01": "300" },
        },
        euroEcuRates: {
          "1999-01": { USD: "1.2", CHF: "1.8", GBP: "0.8" },
        },
      }),
    ).toThrowError("XAU price for 1999-01 must be positive");
  });

  test("uses half-even rounding and switches from XEU to EUR at 1999-01", () => {
    const prices = {
      "1998-12": "1.2345665",
      "1999-01": "1.2345675",
    };
    const publication = buildPublication({
      from: "1998-12",
      through: "1999-01",
      publishedAt: "2026-07-20T10:00:00.000Z",
      metalPricesUsd: {
        XAU: prices,
        XAG: prices,
        XPT: prices,
        XPD: prices,
      },
      euroEcuRates: {
        "1998-12": { USD: "1", CHF: "1", GBP: "1" },
        "1999-01": { USD: "1", CHF: "1", GBP: "1" },
      },
    });

    expect(publication.snapshot.series[0]?.observations).toEqual([
      {
        month: "1998-12",
        prices: {
          USD: "1.234566",
          XEU: "1.234566",
          CHF: "1.234566",
          GBP: "1.234566",
        },
      },
      {
        month: "1999-01",
        prices: {
          USD: "1.234568",
          EUR: "1.234568",
          CHF: "1.234568",
          GBP: "1.234568",
        },
      },
    ]);
    expect(publication.manifest.currencies).toEqual({
      USD: { from: "1998-12", through: "1999-01" },
      CHF: { from: "1998-12", through: "1999-01" },
      GBP: { from: "1998-12", through: "1999-01" },
      XEU: { from: "1998-12", through: "1998-12" },
      EUR: { from: "1999-01", through: "1999-01" },
    });
  });

  test("keeps snapshot bytes and SHA-256 deterministic across publication times", () => {
    const input = {
      from: "1999-01" as const,
      through: "1999-01" as const,
      metalPricesUsd: {
        XAU: { "1999-01": "500" },
        XAG: { "1999-01": "10" },
        XPT: { "1999-01": "600" },
        XPD: { "1999-01": "300" },
      },
      euroEcuRates: {
        "1999-01": { USD: "1.2", CHF: "1.8", GBP: "0.8" },
      },
    };
    const first = buildPublication({
      ...input,
      publishedAt: "2026-07-20T10:00:00.000Z",
    });
    const second = buildPublication({
      ...input,
      publishedAt: "2026-07-21T10:00:00.000Z",
    });

    expect(first.dataBytes.equals(second.dataBytes)).toBe(true);
    expect(first.manifest.dataVersion).toBe(second.manifest.dataVersion);
    expect(first.manifestBytes.equals(second.manifestBytes)).toBe(false);
    expect(first.dataBytes.at(-1)).toBe(10);
  });

  test("rejects non-positive exchange rates", () => {
    expect(() =>
      buildPublication({
        from: "1999-01",
        through: "1999-01",
        publishedAt: "2026-07-20T10:00:00.000Z",
        metalPricesUsd: {
          XAU: { "1999-01": "500" },
          XAG: { "1999-01": "10" },
          XPT: { "1999-01": "600" },
          XPD: { "1999-01": "300" },
        },
        euroEcuRates: {
          "1999-01": { USD: "0", CHF: "1.8", GBP: "0.8" },
        },
      }),
    ).toThrowError("USD exchange rate for 1999-01 must be positive");
  });
});
