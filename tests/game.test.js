const test = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { mkdtempSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');

test('Elm の盤面生成、六角隣接、推理、勝敗、毛布', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'nekomine-elm-test-'));
  try {
    const output = join(dir, 'verify.js');
    execFileSync('elm', ['make', 'tests/Verify.elm', '--output=' + output], { stdio: 'pipe' });
    const Elm = require(output).Elm;
    const app = Elm.Verify.init();
    const checks = await new Promise(resolve => app.ports.result.subscribe(resolve));
    assert.deepEqual(checks, Array(checks.length).fill(true));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
