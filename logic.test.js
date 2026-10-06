const test = require('node:test');
const assert = require('node:assert');
const { createBoard, reveal, toggleFlag, isWon, BREEDS, pickBreed, caughtCats, addToDex } = require('./logic.js');

const count = (b, f) => b.cells.flat().filter(f).length;

test('指定数の猫が配置され、最初のマスと周囲には猫がいない', () => {
  for (let i = 0; i < 50; i++) {
    const b = createBoard(9, 9, 10, 4, 4);
    assert.strictEqual(count(b, (c) => c.cat), 10);
    for (let dr = -1; dr <= 1; dr++)
      for (let dc = -1; dc <= 1; dc++) assert.ok(!b.cells[4 + dr][4 + dc].cat);
  }
});

test('隣接猫数 n が正しい', () => {
  const b = createBoard(9, 9, 10, 0, 0);
  for (let r = 0; r < 9; r++)
    for (let c = 0; c < 9; c++) {
      let n = 0;
      for (let dr = -1; dr <= 1; dr++)
        for (let dc = -1; dc <= 1; dc++) if (b.cells[r + dr]?.[c + dc]?.cat && (dr || dc)) n++;
      assert.strictEqual(b.cells[r][c].n, n);
    }
});

// 手で盤面を作るヘルパ: '*' = 猫
const fromMap = (rows) => {
  const b = createBoard(rows.length, rows[0].length, 0, 0, 0);
  rows.forEach((row, r) => [...row].forEach((ch, c) => (b.cells[r][c].cat = ch === '*')));
  b.cells.forEach((row, r) => row.forEach((cell, c) => {
    cell.n = 0;
    for (let dr = -1; dr <= 1; dr++)
      for (let dc = -1; dc <= 1; dc++) if ((dr || dc) && b.cells[r + dr]?.[c + dc]?.cat) cell.n++;
  }));
  return b;
};

test('0のマスを開くと連鎖して開く', () => {
  const b = fromMap(['....', '....', '...*']);
  assert.strictEqual(reveal(b, 0, 0), 'ok');
  assert.strictEqual(count(b, (c) => c.open), 11);
  assert.ok(isWon(b));
});

test('猫を開くと boom', () => {
  const b = fromMap(['*.', '..']);
  assert.strictEqual(reveal(b, 0, 0), 'boom');
  assert.ok(!isWon(b));
});

test('旗のマスは開かない・旗はトグル', () => {
  const b = fromMap(['*.', '..']);
  toggleFlag(b, 0, 0);
  assert.strictEqual(reveal(b, 0, 0), 'ok');
  assert.ok(!b.cells[0][0].open);
  toggleFlag(b, 0, 0);
  assert.ok(!b.cells[0][0].flag);
});

test('開いたマスには旗を立てられない', () => {
  const b = fromMap(['*.', '..']);
  reveal(b, 1, 1);
  toggleFlag(b, 1, 1);
  assert.ok(!b.cells[1][1].flag);
});

test('pickBreed は重みどおりに選ぶ（端の値）', () => {
  assert.strictEqual(pickBreed(0), BREEDS[0].id);
  assert.strictEqual(pickBreed(0.999999), BREEDS[BREEDS.length - 1].id);
  const total = BREEDS.reduce((s, x) => s + x.weight, 0);
  assert.strictEqual(pickBreed(BREEDS[0].weight / total), BREEDS[1].id); // 境界ちょうどは次の種類
});

test('盤面の猫にはすべて種類が付く', () => {
  const ids = BREEDS.map((x) => x.id);
  const b = createBoard(16, 16, 40, 0, 0);
  for (const c of b.cells.flat().filter((c) => c.cat)) assert.ok(ids.includes(c.breed));
});

test('クリアなら全部の猫、負けなら正しく目印した猫だけ捕まえる', () => {
  const b = fromMap(['*.*', '...']);
  b.cells[0][0].breed = 'mike';
  b.cells[0][2].breed = 'kuro';
  assert.deepStrictEqual(caughtCats(b, true).sort(), ['kuro', 'mike']);
  toggleFlag(b, 0, 2);
  toggleFlag(b, 1, 1); // 猫じゃないマスの目印は数えない
  assert.deepStrictEqual(caughtCats(b, false), ['kuro']);
});

test('addToDex は数を足し、初めての種類を返す（元の図鑑は変えない）', () => {
  const dex = { kuro: 2 };
  const { dex: next, fresh } = addToDex(dex, ['kuro', 'mike', 'mike']);
  assert.deepStrictEqual(next, { kuro: 3, mike: 2 });
  assert.deepStrictEqual(fresh, ['mike']);
  assert.deepStrictEqual(dex, { kuro: 2 });
});
