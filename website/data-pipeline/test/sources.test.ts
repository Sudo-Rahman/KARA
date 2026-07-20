import { readFile } from "node:fs/promises";

import ExcelJS from "exceljs";
import { describe, expect, test } from "vitest";

import { parseEurostatCsv } from "../src/sources/eurostat.js";
import { parseImfWorkbook } from "../src/sources/imf.js";

const fixtureUrl = (name: string): URL =>
  new URL(`./fixtures/${name}`, import.meta.url);

describe("IMF monthly workbook parser", () => {
  test("discovers the four series by code and preserves leading gaps", async () => {
    const encoded = await readFile(
      fixtureUrl("imf-monthly.xlsx.base64"),
      "utf8",
    );
    const prices = await parseImfWorkbook(
      Buffer.from(encoded.trim(), "base64"),
    );

    expect(prices).toEqual({
      XAU: {
        "1986-12": "390.125",
        "1987-01": "410.5",
        "1987-02": "420.75",
      },
      XAG: {
        "1986-12": "5.375",
        "1987-01": "5.75",
        "1987-02": "5.875",
      },
      XPT: {
        "1986-12": "480.25",
        "1987-01": "510.125",
        "1987-02": "520.625",
      },
      XPD: {
        "1987-01": "115.25",
        "1987-02": "125.5",
      },
    });
  });

  test("rejects a workbook that is not an XLSX document", async () => {
    await expect(
      parseImfWorkbook(Buffer.from("not an xlsx", "utf8")),
    ).rejects.toThrow(/Invalid IMF workbook/);
  });

  test("rejects a target series that is not expressed per troy ounce", async () => {
    const encoded = await readFile(
      fixtureUrl("imf-monthly.xlsx.base64"),
      "utf8",
    );
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(
      Buffer.from(
        encoded.trim(),
        "base64",
      ) as unknown as Parameters<typeof workbook.xlsx.load>[0],
    );
    workbook.getWorksheet("External")!.getCell(2, 2).value =
      "Gold, USD per kilogram";
    const bytes = Buffer.from(await workbook.xlsx.writeBuffer());

    await expect(parseImfWorkbook(bytes)).rejects.toThrow(
      "IMF series PGOLD is not expressed per troy ounce",
    );
  });
});

describe("Eurostat SDMX-CSV parser", () => {
  test("validates dimensions and joins the three currencies by month", async () => {
    const csv = await readFile(fixtureUrl("eurostat-monthly.csv"), "utf8");

    expect(parseEurostatCsv(csv)).toEqual({
      "1987-01": { USD: "1.1000", CHF: "1.6500", GBP: "0.6950" },
      "1987-02": { USD: "1.1250", CHF: "1.6750", GBP: "0.7000" },
    });
  });

  test("rejects a duplicate currency observation", async () => {
    const csv = await readFile(fixtureUrl("eurostat-monthly.csv"), "utf8");
    const duplicated = `${csv}${csv.trimEnd().split("\n").at(-1)}\n`;

    expect(() => parseEurostatCsv(duplicated)).toThrow(
      "Duplicate Eurostat USD observation for 1987-02",
    );
  });

  test("rejects an unexpected aggregation", async () => {
    const csv = await readFile(fixtureUrl("eurostat-monthly.csv"), "utf8");

    expect(() => parseEurostatCsv(csv.replace(",AVG,", ",END,"))).toThrow(
      /Unexpected Eurostat statinfo/,
    );
  });
});
