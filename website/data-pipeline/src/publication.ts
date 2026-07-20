import { createHash } from "node:crypto";

import { Decimal } from "decimal.js";

export const METALS = ["XAU", "XAG", "XPT", "XPD"] as const;

export type MetalCode = (typeof METALS)[number];
export type Month = `${number}-${string}`;

export interface EuroEcuRate {
  readonly USD: string;
  readonly CHF: string;
  readonly GBP: string;
}

export interface PublicationInput {
  readonly from: Month;
  readonly through: Month;
  readonly publishedAt: string;
  readonly metalPricesUsd: Readonly<
    Record<MetalCode, Readonly<Record<string, string>>>
  >;
  readonly euroEcuRates: Readonly<Record<string, EuroEcuRate>>;
}

export interface PriceSet {
  readonly USD: string;
  readonly EUR?: string;
  readonly XEU?: string;
  readonly CHF: string;
  readonly GBP: string;
}

export interface Observation {
  readonly month: Month;
  readonly prices: PriceSet;
}

export interface MetalSeries {
  readonly metal: MetalCode;
  readonly observations: readonly Observation[];
}

export interface SourceAttribution {
  readonly id: string;
  readonly role: "metal_prices_usd" | "exchange_rates";
  readonly title: string;
  readonly url: string;
  readonly attribution: string;
  readonly termsUrl: string;
}

export interface DataSnapshot {
  readonly schemaVersion: 1;
  readonly datasetId: "precious-metals-monthly";
  readonly frequency: "monthly";
  readonly priceKind: "monthly_average";
  readonly unit: {
    readonly code: "troy_ounce";
    readonly grams: "31.1034768";
  };
  readonly methodology: {
    readonly nominal: true;
    readonly currencyConversion: "ratio_of_monthly_average_rates";
    readonly roundingDecimals: 6;
    readonly roundingMode: "half_even";
  };
  readonly sources: readonly SourceAttribution[];
  readonly series: readonly MetalSeries[];
}

interface Coverage {
  readonly from: Month;
  readonly through: Month;
}

export interface Manifest {
  readonly schemaVersion: 1;
  readonly datasetId: "precious-metals-monthly";
  readonly dataVersion: string;
  readonly publishedAt: string;
  readonly metals: typeof METALS;
  readonly coverage: Coverage;
  readonly currencies: Readonly<Record<string, Coverage>>;
  readonly file: {
    readonly url: "/v1/metals-monthly.json";
    readonly sha256: string;
    readonly bytes: number;
  };
}

export interface Publication {
  readonly snapshot: DataSnapshot;
  readonly manifest: Manifest;
  readonly dataBytes: Buffer;
  readonly manifestBytes: Buffer;
}

const ExactDecimal = Decimal.clone({
  precision: 40,
  rounding: Decimal.ROUND_HALF_EVEN,
});

const SOURCES: readonly SourceAttribution[] = [
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
];

function formatPrice(value: Decimal): string {
  return value.toDecimalPlaces(6).toFixed(6);
}

function convertPrices(usdValue: string, rate: EuroEcuRate, month: Month): PriceSet {
  const usd = new ExactDecimal(usdValue);
  const usdPerEuroEcu = new ExactDecimal(rate.USD);
  const commonCurrencyPrice = usd.dividedBy(usdPerEuroEcu);

  const prices: PriceSet = {
    USD: formatPrice(usd),
    ...(month < "1999-01"
      ? { XEU: formatPrice(commonCurrencyPrice) }
      : { EUR: formatPrice(commonCurrencyPrice) }),
    CHF: formatPrice(
      usd.times(new ExactDecimal(rate.CHF)).dividedBy(usdPerEuroEcu),
    ),
    GBP: formatPrice(
      usd.times(new ExactDecimal(rate.GBP)).dividedBy(usdPerEuroEcu),
    ),
  };

  return prices;
}

function currencyCoverage(from: Month, through: Month): Readonly<Record<string, Coverage>> {
  const coverage: Record<string, Coverage> = {
    USD: { from, through },
    CHF: { from, through },
    GBP: { from, through },
  };

  if (from < "1999-01") {
    coverage.XEU = {
      from,
      through: through < "1999-01" ? through : "1998-12",
    };
  }

  if (through >= "1999-01") {
    coverage.EUR = {
      from: from >= "1999-01" ? from : "1999-01",
      through,
    };
  }

  return coverage;
}

function canonicalBytes(value: unknown): Buffer {
  return Buffer.from(`${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function monthSequence(from: Month, through: Month): Month[] {
  if (from > through) {
    throw new Error(`Coverage starts after it ends: ${from} > ${through}`);
  }

  const [fromYear, fromMonth] = from.split("-").map(Number);
  const [throughYear, throughMonth] = through.split("-").map(Number);
  const months: Month[] = [];

  let year = fromYear!;
  let month = fromMonth!;
  while (year < throughYear! || (year === throughYear && month <= throughMonth!)) {
    months.push(`${year}-${String(month).padStart(2, "0")}` as Month);
    month += 1;
    if (month === 13) {
      year += 1;
      month = 1;
    }
  }

  return months;
}

function requiredExchangeRate(
  rates: Readonly<Record<string, EuroEcuRate>>,
  month: Month,
): EuroEcuRate {
  const value = rates[month];
  if (value === undefined) {
    throw new Error(`Missing exchange rates for ${month}`);
  }

  for (const currency of ["USD", "CHF", "GBP"] as const) {
    let decimal: Decimal;
    try {
      decimal = new ExactDecimal(value[currency]);
    } catch {
      throw new Error(
        `${currency} exchange rate for ${month} must be a decimal`,
      );
    }
    if (!decimal.isFinite() || !decimal.greaterThan(0)) {
      throw new Error(
        `${currency} exchange rate for ${month} must be positive`,
      );
    }
  }

  return value;
}

function requiredMetalPrice(
  prices: Readonly<Record<string, string>>,
  metal: MetalCode,
  month: Month,
): string {
  const value = prices[month];
  if (value === undefined) {
    throw new Error(`Missing ${metal} price for ${month}`);
  }

  const decimal = new ExactDecimal(value);
  if (!decimal.isFinite() || !decimal.greaterThan(0)) {
    throw new Error(`${metal} price for ${month} must be positive`);
  }

  return value;
}

export function buildPublication(input: PublicationInput): Publication {
  const months = monthSequence(input.from, input.through);

  const series = METALS.map((metal): MetalSeries => ({
    metal,
    observations: months.map((month): Observation => ({
      month,
      prices: convertPrices(
        requiredMetalPrice(input.metalPricesUsd[metal], metal, month),
        requiredExchangeRate(input.euroEcuRates, month),
        month,
      ),
    })),
  }));

  const snapshot: DataSnapshot = {
    schemaVersion: 1,
    datasetId: "precious-metals-monthly",
    frequency: "monthly",
    priceKind: "monthly_average",
    unit: {
      code: "troy_ounce",
      grams: "31.1034768",
    },
    methodology: {
      nominal: true,
      currencyConversion: "ratio_of_monthly_average_rates",
      roundingDecimals: 6,
      roundingMode: "half_even",
    },
    sources: SOURCES,
    series,
  };

  const dataBytes = canonicalBytes(snapshot);
  const dataVersion = createHash("sha256").update(dataBytes).digest("hex");
  const manifest: Manifest = {
    schemaVersion: 1,
    datasetId: "precious-metals-monthly",
    dataVersion,
    publishedAt: input.publishedAt,
    metals: METALS,
    coverage: { from: input.from, through: input.through },
    currencies: currencyCoverage(input.from, input.through),
    file: {
      url: "/v1/metals-monthly.json",
      sha256: dataVersion,
      bytes: dataBytes.byteLength,
    },
  };

  return {
    snapshot,
    manifest,
    dataBytes,
    manifestBytes: canonicalBytes(manifest),
  };
}
