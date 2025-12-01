import { createRequire } from 'module';
import { resolve } from 'path';
import { readFileSync, writeFileSync } from 'fs';

// playwright is globally installed; createRequire resolves it via CJS from the known path
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/lib/node_modules/playwright');

const argv = process.argv.slice(2);
const input = resolve(argv[argv.indexOf('--input') + 1]);
const output = resolve(argv[argv.indexOf('--output') + 1]);

const browser = await chromium.launch({ args: ['--no-sandbox'] });
const ctx = await browser.newContext({ locale: 'en-US', timezoneId: 'UTC' });
const page = await ctx.newPage();
await page.goto('file://' + input, { waitUntil: 'networkidle' });
await page.pdf({
    path: output,
    format: 'A4',
    printBackground: true,
    margin: { top: '20mm', right: '20mm', bottom: '20mm', left: '20mm' },
});
await browser.close();

// Chromium stamps CreationDate/ModDate with the render time, so every run
// yields different bytes.  Zero the timestamps with an equal-length rewrite
// (byte offsets stay valid) so manifests hash identically across runs.
const bytes = readFileSync(output).toString('latin1');
writeFileSync(
    output,
    Buffer.from(
        bytes
            .replace(/\/CreationDate \(D:[^)]*\)/, "/CreationDate (D:00000000000000+00'00')")
            .replace(/\/ModDate \(D:[^)]*\)/, "/ModDate (D:00000000000000+00'00')"),
        'latin1',
    ),
);
