import { createHash } from "node:crypto";

import { Decimal } from "decimal.js";
import { z } from "zod";

const monthSchema = z
  .string()
  .regex(/^\d{4}-(0[1-9]|1[0-2])$/, "Expected month in YYYY-MM format");

const coverageSchema = z
  .object({
    from: monthSchema,
    through: monthSchema,
  })
  .passthrough()
  .refine((coverage) => coverage.from <= coverage.through, {
    message: "Coverage start must not be after coverage end",
  });

const priceSchema = z
  .string()
  .regex(/^\d+\.\d{6}$/, "Expected a decimal string with six places")
  .refine((value) => new Decimal(value).greaterThan(0), {
    message: "Price must be positive",
  });

const preEuroPricesSchema = z
  .object({
    USD: priceSchema,
    XEU: priceSchema,
    CHF: priceSchema,
    GBP: priceSchema,
  })
  .passthrough();

const euroPricesSchema = z
  .object({
    USD: priceSchema,
    EUR: priceSchema,
    CHF: priceSchema,
    GBP: priceSchema,
  })
  .passthrough();

const observationSchema = z
  .object({
    month: monthSchema,
    prices: z.union([preEuroPricesSchema, euroPricesSchema]),
  })
  .passthrough()
  .superRefine((observation, context) => {
    const usesXeu = "XEU" in observation.prices;
    const usesEur = "EUR" in observation.prices;
    if (usesXeu === usesEur) {
      context.addIssue({
        code: "custom",
        message: "Prices must contain exactly one of XEU or EUR",
        path: ["prices"],
      });
    }
    if (observation.month < "1999-01" && !usesXeu) {
      context.addIssue({
        code: "custom",
        message: "Months before 1999 must use XEU",
        path: ["prices"],
      });
    }
    if (observation.month >= "1999-01" && usesXeu) {
      context.addIssue({
        code: "custom",
        message: "Months from 1999 must use EUR",
        path: ["prices"],
      });
    }
  });

const sourceSchema = z
  .object({
    id: z.string().min(1),
    role: z.enum(["metal_prices_usd", "exchange_rates"]),
    title: z.string().min(1),
    url: z.url(),
    attribution: z.string().min(1),
    termsUrl: z.url(),
  })
  .passthrough();

const seriesSchema = z
  .object({
    metal: z.enum(["XAU", "XAG", "XPT", "XPD"]),
    observations: z.array(observationSchema).min(1),
  })
  .passthrough();

function monthIndex(month: string): number {
  const [year, number] = month.split("-").map(Number);
  return year! * 12 + number! - 1;
}

export const snapshotSchema = z
  .object({
    schemaVersion: z.literal(1),
    datasetId: z.literal("precious-metals-monthly"),
    frequency: z.literal("monthly"),
    priceKind: z.literal("monthly_average"),
    unit: z
      .object({
        code: z.literal("troy_ounce"),
        grams: z.literal("31.1034768"),
      })
      .passthrough(),
    methodology: z
      .object({
        nominal: z.literal(true),
        currencyConversion: z.literal("ratio_of_monthly_average_rates"),
        roundingDecimals: z.literal(6),
        roundingMode: z.literal("half_even"),
      })
      .passthrough(),
    sources: z.array(sourceSchema).min(2),
    series: z.array(seriesSchema).length(4),
  })
  .passthrough()
  .superRefine((snapshot, context) => {
    const expectedMetals = ["XAU", "XAG", "XPT", "XPD"] as const;
    const referenceMonths = snapshot.series[0]!.observations.map(
      (observation) => observation.month,
    );

    snapshot.series.forEach((series, seriesIndex) => {
      if (series.metal !== expectedMetals[seriesIndex]) {
        context.addIssue({
          code: "custom",
          message: `Expected metal ${expectedMetals[seriesIndex]} at index ${seriesIndex}`,
          path: ["series", seriesIndex, "metal"],
        });
      }

      const months = series.observations.map(
        (observation) => observation.month,
      );
      if (
        months.length !== referenceMonths.length ||
        months.some((month, index) => month !== referenceMonths[index])
      ) {
        context.addIssue({
          code: "custom",
          message: "All metal series must have identical months",
          path: ["series", seriesIndex, "observations"],
        });
      }

      for (let index = 1; index < months.length; index += 1) {
        if (monthIndex(months[index]!) !== monthIndex(months[index - 1]!) + 1) {
          context.addIssue({
            code: "custom",
            message: "Observation months must be strictly increasing and continuous",
            path: ["series", seriesIndex, "observations", index, "month"],
          });
        }
      }
    });
  });

const currenciesSchema = z
  .object({
    USD: coverageSchema,
    CHF: coverageSchema,
    GBP: coverageSchema,
    XEU: coverageSchema.optional(),
    EUR: coverageSchema.optional(),
  })
  .passthrough();

const sha256Schema = z
  .string()
  .regex(/^[0-9a-f]{64}$/, "Expected a lowercase SHA-256");

export const manifestSchema = z
  .object({
    schemaVersion: z.literal(1),
    datasetId: z.literal("precious-metals-monthly"),
    dataVersion: sha256Schema,
    publishedAt: z
      .string()
      .regex(
        /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/,
        "Expected an ISO-8601 UTC timestamp",
      )
      .refine((value) => Number.isFinite(Date.parse(value)), {
        message: "Invalid publication timestamp",
      }),
    metals: z.tuple([
      z.literal("XAU"),
      z.literal("XAG"),
      z.literal("XPT"),
      z.literal("XPD"),
    ]),
    coverage: coverageSchema,
    currencies: currenciesSchema,
    file: z
      .object({
        url: z.literal("/v1/metals-monthly.json"),
        sha256: sha256Schema,
        bytes: z.number().int().positive(),
      })
      .passthrough(),
  })
  .passthrough()
  .superRefine((manifest, context) => {
    if (
      manifest.dataVersion !== manifest.file.sha256
    ) {
      context.addIssue({
        code: "custom",
        message: "dataVersion and file.sha256 must match",
        path: ["file", "sha256"],
      });
    }

    for (const currency of ["USD", "CHF", "GBP"] as const) {
      const coverage = manifest.currencies[currency];
      if (
        coverage.from !== manifest.coverage.from ||
        coverage.through !== manifest.coverage.through
      ) {
        context.addIssue({
          code: "custom",
          message: `${currency} coverage must equal dataset coverage`,
          path: ["currencies", currency],
        });
      }
    }

    const needsXeu = manifest.coverage.from < "1999-01";
    const expectedXeuThrough =
      manifest.coverage.through < "1999-01"
        ? manifest.coverage.through
        : "1998-12";
    if (
      needsXeu
        ? manifest.currencies.XEU?.from !== manifest.coverage.from ||
          manifest.currencies.XEU?.through !== expectedXeuThrough
        : manifest.currencies.XEU !== undefined
    ) {
      context.addIssue({
        code: "custom",
        message: "XEU coverage is inconsistent with dataset coverage",
        path: ["currencies", "XEU"],
      });
    }

    const needsEur = manifest.coverage.through >= "1999-01";
    const expectedEurFrom =
      manifest.coverage.from >= "1999-01"
        ? manifest.coverage.from
        : "1999-01";
    if (
      needsEur
        ? manifest.currencies.EUR?.from !== expectedEurFrom ||
          manifest.currencies.EUR?.through !== manifest.coverage.through
        : manifest.currencies.EUR !== undefined
    ) {
      context.addIssue({
        code: "custom",
        message: "EUR coverage is inconsistent with dataset coverage",
        path: ["currencies", "EUR"],
      });
    }
  });

export type DecodedManifest = z.infer<typeof manifestSchema>;
export type DecodedSnapshot = z.infer<typeof snapshotSchema>;

function parseJson(bytes: Buffer, label: string): unknown {
  try {
    return JSON.parse(bytes.toString("utf8"));
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Invalid ${label} JSON: ${message}`, { cause: error });
  }
}

export function parseManifestBytes(bytes: Buffer): DecodedManifest {
  return manifestSchema.parse(parseJson(bytes, "manifest"));
}

export function verifyPublicationFiles(
  manifestBytes: Buffer,
  snapshotBytes: Buffer,
): {
  readonly manifest: DecodedManifest;
  readonly snapshot: DecodedSnapshot;
} {
  const manifest = parseManifestBytes(manifestBytes);
  if (snapshotBytes.byteLength !== manifest.file.bytes) {
    throw new Error(
      `Snapshot byte count does not match manifest: expected ${manifest.file.bytes}, got ${snapshotBytes.byteLength}`,
    );
  }

  const sha256 = createHash("sha256").update(snapshotBytes).digest("hex");
  if (sha256 !== manifest.dataVersion || sha256 !== manifest.file.sha256) {
    throw new Error("Snapshot SHA-256 does not match manifest");
  }

  const snapshot = snapshotSchema.parse(parseJson(snapshotBytes, "snapshot"));
  const observations = snapshot.series[0]!.observations;
  const first = observations[0]!.month;
  const through = observations[observations.length - 1]!.month;
  if (
    first !== manifest.coverage.from ||
    through !== manifest.coverage.through
  ) {
    throw new Error("Snapshot coverage does not match manifest");
  }

  return { manifest, snapshot };
}
