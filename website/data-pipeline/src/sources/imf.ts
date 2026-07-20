import { Decimal } from "decimal.js";
import ExcelJS from "exceljs";

import type { MetalCode, Month } from "../publication.js";

const SERIES_BY_METAL: Readonly<Record<MetalCode, string>> = {
  XAU: "PGOLD",
  XAG: "PSILVER",
  XPT: "PPLAT",
  XPD: "PPALLA",
};
const TARGET_SERIES = new Set(Object.values(SERIES_BY_METAL));

const MAX_WORKBOOK_BYTES = 20 * 1024 * 1024;
const MONTH_PATTERN = /^(\d{4})M([1-9]|1[0-2])$/;

export type MetalPricesUsd = Readonly<
  Record<MetalCode, Readonly<Record<string, string>>>
>;

function normalizeMonth(value: string): Month {
  const match = MONTH_PATTERN.exec(value);
  if (match === null) {
    throw new Error(`Unexpected IMF month: ${value}`);
  }

  return `${match[1]}-${match[2]!.padStart(2, "0")}` as Month;
}

function decimalCell(cell: ExcelJS.Cell, series: string, month: Month): string | undefined {
  const value = cell.value;
  if (value === null || value === undefined || value === "") {
    return undefined;
  }

  if (typeof value !== "number" && typeof value !== "string") {
    throw new Error(`Unexpected IMF ${series} cell type for ${month}`);
  }

  const text = String(value).trim();
  let decimal: Decimal;
  try {
    decimal = new Decimal(text);
  } catch {
    throw new Error(`Invalid IMF ${series} value for ${month}: ${text}`);
  }

  if (!decimal.isFinite() || !decimal.greaterThan(0)) {
    throw new Error(`IMF ${series} value for ${month} must be positive`);
  }

  return text;
}

function monthIndex(month: string): number {
  const [year, number] = month.split("-").map(Number);
  return year! * 12 + number! - 1;
}

function assertContinuous(series: string, values: Readonly<Record<string, string>>): void {
  const months = Object.keys(values).sort();
  if (months.length === 0) {
    throw new Error(`IMF series ${series} has no observations`);
  }

  for (let index = 1; index < months.length; index += 1) {
    if (monthIndex(months[index]!) !== monthIndex(months[index - 1]!) + 1) {
      throw new Error(
        `IMF series ${series} has a gap between ${months[index - 1]} and ${months[index]}`,
      );
    }
  }
}

function headerText(sheet: ExcelJS.Worksheet, row: number, column: number): string {
  return sheet.getCell(row, column).text.trim();
}

export async function parseImfWorkbook(bytes: Buffer): Promise<MetalPricesUsd> {
  try {
    if (bytes.byteLength === 0 || bytes.byteLength > MAX_WORKBOOK_BYTES) {
      throw new Error(
        `workbook size must be between 1 and ${MAX_WORKBOOK_BYTES} bytes`,
      );
    }

    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(
      bytes as unknown as Parameters<typeof workbook.xlsx.load>[0],
    );
    const sheet = workbook.getWorksheet("External");
    if (sheet === undefined) {
      throw new Error('missing worksheet "External"');
    }

    const columnsByCode = new Map<string, number>();
    for (let column = 1; column <= sheet.columnCount; column += 1) {
      const code = headerText(sheet, 1, column);
      if (code === "" || !TARGET_SERIES.has(code)) {
        continue;
      }
      if (columnsByCode.has(code)) {
        throw new Error(`duplicate IMF series header: ${code}`);
      }
      columnsByCode.set(code, column);
    }

    const output: Record<MetalCode, Record<string, string>> = {
      XAU: {},
      XAG: {},
      XPT: {},
      XPD: {},
    };

    for (const [metal, series] of Object.entries(SERIES_BY_METAL) as [
      MetalCode,
      string,
    ][]) {
      const column = columnsByCode.get(series);
      if (column === undefined) {
        throw new Error(`missing IMF series: ${series}`);
      }
      if (headerText(sheet, 3, column) !== "USD") {
        throw new Error(`IMF series ${series} is not denominated in USD`);
      }
      if (!/\btroy\s+ounce\b/i.test(headerText(sheet, 2, column))) {
        throw new Error(
          `IMF series ${series} is not expressed per troy ounce`,
        );
      }
      if (headerText(sheet, 4, column) !== "Monthly") {
        throw new Error(`IMF series ${series} is not monthly`);
      }

      for (let row = 5; row <= sheet.rowCount; row += 1) {
        const sourceMonth = headerText(sheet, row, 1);
        if (sourceMonth === "") {
          continue;
        }
        const month = normalizeMonth(sourceMonth);
        const price = decimalCell(sheet.getCell(row, column), series, month);
        if (price === undefined) {
          continue;
        }
        if (output[metal][month] !== undefined) {
          throw new Error(`duplicate IMF ${series} observation for ${month}`);
        }
        output[metal][month] = price;
      }

      assertContinuous(series, output[metal]);
    }

    return output;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Invalid IMF workbook: ${message}`, { cause: error });
  }
}
