import { parse } from "csv-parse/sync";
import { Decimal } from "decimal.js";

import type { EuroEcuRate, Month } from "../publication.js";

const CURRENCIES = ["USD", "CHF", "GBP"] as const;
type Currency = (typeof CURRENCIES)[number];

const DATAFLOW = "ESTAT:ERT_BIL_EUR_M(1.0)";
const MONTH_PATTERN = /^\d{4}-(0[1-9]|1[0-2])$/;
const REQUIRED_COLUMNS = [
  "DATAFLOW",
  "freq",
  "statinfo",
  "unit",
  "currency",
  "TIME_PERIOD",
  "OBS_VALUE",
] as const;

type CsvRow = Record<string, string>;

function monthIndex(month: string): number {
  const [year, number] = month.split("-").map(Number);
  return year! * 12 + number! - 1;
}

function assertContinuous(currency: Currency, months: readonly string[]): void {
  for (let index = 1; index < months.length; index += 1) {
    if (monthIndex(months[index]!) !== monthIndex(months[index - 1]!) + 1) {
      throw new Error(
        `Eurostat ${currency} has a gap between ${months[index - 1]} and ${months[index]}`,
      );
    }
  }
}

function validateValue(value: string, currency: Currency, month: Month): string {
  let decimal: Decimal;
  try {
    decimal = new Decimal(value);
  } catch {
    throw new Error(`Invalid Eurostat ${currency} value for ${month}: ${value}`);
  }

  if (!decimal.isFinite() || !decimal.greaterThan(0)) {
    throw new Error(`Eurostat ${currency} value for ${month} must be positive`);
  }

  return value;
}

export function parseEurostatCsv(input: string | Buffer): Readonly<
  Record<string, EuroEcuRate>
> {
  let rows: CsvRow[];
  try {
    rows = parse(input, {
      bom: true,
      columns: true,
      skip_empty_lines: true,
    }) as CsvRow[];
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Invalid Eurostat CSV: ${message}`, { cause: error });
  }

  if (rows.length === 0) {
    throw new Error("Invalid Eurostat CSV: no observations");
  }
  for (const column of REQUIRED_COLUMNS) {
    if (!(column in rows[0]!)) {
      throw new Error(`Invalid Eurostat CSV: missing column ${column}`);
    }
  }

  const byCurrency: Record<Currency, Record<string, string>> = {
    USD: {},
    CHF: {},
    GBP: {},
  };

  for (const row of rows) {
    if (row.DATAFLOW !== DATAFLOW) {
      throw new Error(`Unexpected Eurostat DATAFLOW: ${row.DATAFLOW}`);
    }
    if (row.freq !== "M") {
      throw new Error(`Unexpected Eurostat frequency: ${row.freq}`);
    }
    if (row.statinfo !== "AVG") {
      throw new Error(`Unexpected Eurostat statinfo: ${row.statinfo}`);
    }
    if (row.unit !== "NAC") {
      throw new Error(`Unexpected Eurostat unit: ${row.unit}`);
    }
    if (!CURRENCIES.includes(row.currency as Currency)) {
      throw new Error(`Unexpected Eurostat currency: ${row.currency}`);
    }
    if (!MONTH_PATTERN.test(row.TIME_PERIOD ?? "")) {
      throw new Error(`Unexpected Eurostat month: ${row.TIME_PERIOD}`);
    }

    const currency = row.currency as Currency;
    const month = row.TIME_PERIOD as Month;
    if (byCurrency[currency][month] !== undefined) {
      throw new Error(`Duplicate Eurostat ${currency} observation for ${month}`);
    }
    byCurrency[currency][month] = validateValue(
      row.OBS_VALUE ?? "",
      currency,
      month,
    );
  }

  const monthLists = Object.fromEntries(
    CURRENCIES.map((currency) => {
      const months = Object.keys(byCurrency[currency]).sort();
      if (months.length === 0) {
        throw new Error(`Eurostat CSV has no ${currency} observations`);
      }
      assertContinuous(currency, months);
      return [currency, months];
    }),
  ) as Record<Currency, string[]>;

  const reference = monthLists.USD;
  for (const currency of ["CHF", "GBP"] as const) {
    if (
      monthLists[currency].length !== reference.length ||
      monthLists[currency].some((month, index) => month !== reference[index])
    ) {
      throw new Error(`Eurostat ${currency} coverage does not match USD coverage`);
    }
  }

  const output: Record<string, EuroEcuRate> = {};
  for (const month of reference) {
    output[month] = {
      USD: byCurrency.USD[month]!,
      CHF: byCurrency.CHF[month]!,
      GBP: byCurrency.GBP[month]!,
    };
  }

  return output;
}
