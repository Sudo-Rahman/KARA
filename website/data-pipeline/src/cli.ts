#!/usr/bin/env node

import { appendFile } from "node:fs/promises";

import { configFromEnvironment } from "./config.js";
import { runUpdate } from "./update-runner.js";

async function main(): Promise<void> {
  const result = await runUpdate(configFromEnvironment());

  if (process.env.GITHUB_OUTPUT !== undefined) {
    await appendFile(
      process.env.GITHUB_OUTPUT,
      [
        `changed=${String(result.changed)}`,
        `generated=${String(result.generated)}`,
        `status=${result.status}`,
        "",
      ].join("\n"),
      "utf8",
    );
  }

  process.stdout.write(`${JSON.stringify(result)}\n`);
}

try {
  await main();
} catch (error) {
  const message = error instanceof Error ? error.stack ?? error.message : String(error);
  process.stderr.write(`${message}\n`);
  process.exitCode = 1;
}
