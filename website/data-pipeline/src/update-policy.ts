import type {
  EuroEcuRate,
  Manifest,
  MetalCode,
  Month,
} from "./publication.js";
import type { MetalPricesUsd } from "./sources/imf.js";

export const REQUIRED_COMMON_FROM: Month = "1987-01";

export interface Coverage {
  readonly from: Month;
  readonly through: Month;
}

export type Freshness =
  | {
      readonly status: "ready";
      readonly expectedThrough: Month;
      readonly actualThrough: Month;
    }
  | {
      readonly status: "waiting";
      readonly expectedThrough: Month;
      readonly actualThrough: Month;
    };

const MONTH_PATTERN = /^\d{4}-(0[1-9]|1[0-2])$/;

function asMonth(value: string): Month {
  if (!MONTH_PATTERN.test(value)) {
    throw new Error(`Invalid month: ${value}`);
  }
  return value as Month;
}

function monthIndex(month: Month): number {
  const [year, number] = month.split("-").map(Number);
  return year! * 12 + number! - 1;
}

function monthFromIndex(index: number): Month {
  const year = Math.floor(index / 12);
  const month = (index % 12) + 1;
  return `${year}-${String(month).padStart(2, "0")}` as Month;
}

function sortedMonths(values: Readonly<Record<string, unknown>>, name: string): Month[] {
  const months = Object.keys(values).map(asMonth).sort();
  if (months.length === 0) {
    throw new Error(`${name} has no observations`);
  }
  return months;
}

export function previousUtcMonth(now: Date): Month {
  if (!Number.isFinite(now.getTime())) {
    throw new Error("Invalid current time");
  }

  const previous = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1),
  );
  return `${previous.getUTCFullYear()}-${String(
    previous.getUTCMonth() + 1,
  ).padStart(2, "0")}` as Month;
}

export function deriveCommonCoverage(
  metalPricesUsd: MetalPricesUsd,
  euroEcuRates: Readonly<Record<string, EuroEcuRate>>,
  now: Date,
): Coverage {
  const names: readonly MetalCode[] = ["XAU", "XAG", "XPT", "XPD"];
  const metalMonths = Object.fromEntries(
    names.map((metal) => [
      metal,
      sortedMonths(metalPricesUsd[metal], metal),
    ]),
  ) as Record<MetalCode, Month[]>;
  const rateMonths = sortedMonths(euroEcuRates, "exchange rates");

  const firstIndex = Math.max(
    ...names.map((metal) => monthIndex(metalMonths[metal][0]!)),
    monthIndex(rateMonths[0]!),
  );
  const lastIndex = Math.min(
    ...names.map((metal) =>
      monthIndex(metalMonths[metal][metalMonths[metal].length - 1]!),
    ),
    monthIndex(rateMonths[rateMonths.length - 1]!),
    monthIndex(previousUtcMonth(now)),
  );

  if (firstIndex > lastIndex) {
    throw new Error("Sources have no complete common monthly coverage");
  }

  const from = monthFromIndex(firstIndex);
  const through = monthFromIndex(lastIndex);
  if (from !== REQUIRED_COMMON_FROM) {
    throw new Error(
      `Expected common coverage to start at ${REQUIRED_COMMON_FROM}, got ${from}`,
    );
  }

  for (let index = firstIndex; index <= lastIndex; index += 1) {
    const month = monthFromIndex(index);
    for (const metal of names) {
      if (metalPricesUsd[metal][month] === undefined) {
        throw new Error(`Missing ${metal} price for ${month}`);
      }
    }
    if (euroEcuRates[month] === undefined) {
      throw new Error(`Missing exchange rates for ${month}`);
    }
  }

  return { from, through };
}

export function evaluateFreshness(through: Month, now: Date): Freshness {
  const expectedThrough = previousUtcMonth(now);
  if (through >= expectedThrough) {
    return {
      status: "ready",
      expectedThrough,
      actualThrough: through,
    };
  }

  if (monthIndex(through) < monthIndex(expectedThrough) - 1) {
    throw new Error(
      `Source coverage is more than one month behind: expected ${expectedThrough}, got ${through}`,
    );
  }

  return {
    status: "waiting",
    expectedThrough,
    actualThrough: through,
  };
}

export type PublicationClassification = "changed" | "unchanged";

export function classifyPublication(
  candidate: Manifest,
  current?: Manifest,
): PublicationClassification {
  if (current === undefined) {
    return "changed";
  }

  if (
    candidate.coverage.from > current.coverage.from ||
    candidate.coverage.through < current.coverage.through
  ) {
    throw new Error(
      `Coverage regression: current ${current.coverage.from}..${current.coverage.through}, candidate ${candidate.coverage.from}..${candidate.coverage.through}`,
    );
  }

  return candidate.dataVersion === current.dataVersion
    ? "unchanged"
    : "changed";
}
