import { describe, expect, test } from "vitest";

import { buildPublication } from "../src/publication.js";
import {
  manifestSchema,
  snapshotSchema,
  verifyPublicationFiles,
} from "../src/contracts.js";

function publication() {
  return buildPublication({
    from: "1998-12",
    through: "1999-01",
    publishedAt: "2026-07-20T10:00:00.000Z",
    metalPricesUsd: {
      XAU: { "1998-12": "500", "1999-01": "510" },
      XAG: { "1998-12": "10", "1999-01": "11" },
      XPT: { "1998-12": "600", "1999-01": "610" },
      XPD: { "1998-12": "300", "1999-01": "310" },
    },
    euroEcuRates: {
      "1998-12": { USD: "1.2", CHF: "1.8", GBP: "0.8" },
      "1999-01": { USD: "1.1", CHF: "1.7", GBP: "0.7" },
    },
  });
}

describe("public v1 contracts", () => {
  test("decodes matching manifest and snapshot bytes", () => {
    const value = publication();
    const verified = verifyPublicationFiles(
      value.manifestBytes,
      value.dataBytes,
    );

    expect(verified.manifest).toEqual(value.manifest);
    expect(verified.snapshot).toEqual(value.snapshot);
    expect(manifestSchema.parse(value.manifest)).toEqual(value.manifest);
    expect(snapshotSchema.parse(value.snapshot)).toEqual(value.snapshot);
  });

  test("rejects bytes whose hash does not match the manifest", () => {
    const value = publication();
    const tampered = Buffer.concat([value.dataBytes, Buffer.from(" ")]);

    expect(() =>
      verifyPublicationFiles(value.manifestBytes, tampered),
    ).toThrow("Snapshot byte count does not match manifest");
  });

  test("rejects a metal series in the wrong order", () => {
    const value = publication();
    const snapshot = JSON.parse(value.dataBytes.toString("utf8")) as {
      series: unknown[];
    };
    snapshot.series.reverse();

    expect(() => snapshotSchema.parse(snapshot)).toThrow();
  });

  test("rejects EUR before 1999", () => {
    const value = publication();
    const snapshot = JSON.parse(value.dataBytes.toString("utf8")) as {
      series: { observations: { month: string; prices: Record<string, string> }[] }[];
    };
    snapshot.series[0]!.observations[0]!.prices = {
      USD: "500.000000",
      EUR: "416.666667",
      CHF: "750.000000",
      GBP: "333.333333",
    };

    expect(() => snapshotSchema.parse(snapshot)).toThrow();
  });

  test("ignores additive optional v1 fields when decoding", () => {
    const value = publication();
    const manifest = {
      ...value.manifest,
      optionalFutureField: "accepted",
      file: {
        ...value.manifest.file,
        optionalTransportHint: "ignored",
      },
    };
    const snapshot = {
      ...value.snapshot,
      optionalFutureField: "accepted",
    };

    expect(() => manifestSchema.parse(manifest)).not.toThrow();
    expect(() => snapshotSchema.parse(snapshot)).not.toThrow();
  });
});
