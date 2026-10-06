const test = require('node:test');
const assert = require('node:assert');
const { createBoard, reveal, toggleFlag, isWon, neighbors, solvable, BREEDS, pickBreed, caughtCats, addToDex } = require('./logic.js');

const count = (b, f) => b.cells.flat().filter(f).length;
const sorted = (a) => a.map(String).sort();

// 六角形は奇数行を右に半マスずらして並べる
test('六角形の隣は6マス（偶数行・奇数行・端）', () => {
  const b = { rows: 5, cols: 5 };
  assert.deepStrictEqual(sorted(neighbors(b, 2, 2)), sorted([[2, 1], [2, 3], [1, 1], [1, 2], [3, 1], [3, 2]]));
  assert.deepStrictEqual(sorted(neighbors(b, 1, 2)), sorted([[1, 1], [1, 3], [0, 2], [0, 3], [2, 2], [2, 3]]));
  assert.deepStrictEqual(sorted(neighbors(b, 0, 0)), sorted([[0, 1], [1, 0]]));
});

test('指定数の猫が配置され、最初のマスと隣には猫がいない', () => {
  for (let i = 0; i < 20; i++) {
    const b = createBoard(9, 9, 10, 4, 4);
    assert.strictEqual(count(b, (c) => c.cat), 10);
    for (const [r, c] of [[4, 4], ...neighbors(b, 4, 4)]) assert.ok(!b.cells[r][c].cat);
  }
});

test('隣接猫数 n が正しい', () => {
  const b = createBoard(9, 9, 10, 0, 0);
  for (let r = 0; r < 9; r++)
    for (let c = 0; c < 9; c++)
      assert.strictEqual(b.cells[r][c].n, neighbors(b, r, c).filter(([rr, cc]) => b.cells[rr][cc].cat).length);
});

// 手で盤面を作るヘルパ: '*' = 猫
const fromMap = (rows) => {
  const b = createBoard(rows.length, rows[0].length, 0, 0, 0);
  rows.forEach((row, r) => [...row].forEach((ch, c) => (b.cells[r][c].cat = ch === '*')));
  b.cells.forEach((row, r) => row.forEach((cell, c) => {
    cell.n = neighbors(b, r, c).filter(([rr, cc]) => b.cells[rr][cc].cat).length;
  }));
  return b;
};

test('推理だけで解ける盤面は solvable', () => {
  // 左端から開くと 1 の隣が猫と確定し、残りは猫の総数から安全と分かる
  assert.ok(solvable(fromMap(['..*..']), 0, 0));
});

test('二択が残る盤面は solvable ではない', () => {
  // 右端の2マスのどちらかが猫で、手がかりがない
  assert.ok(!solvable(fromMap(['..*.*']), 0, 0));
});

test('solvable は盤面を書き換えない', () => {
  const b = fromMap(['..*..']);
  solvable(b, 0, 0);
  assert.strictEqual(count(b, (c) => c.open), 0);
});

test('作られる盤面はどの難易度でも推理だけで解ける', () => {
  for (const [rows, cols, cats] of [[9, 9, 10], [16, 16, 40], [16, 30, 99]])
    for (let i = 0; i < 3; i++) {
      const sr = Math.floor(rows / 2), sc = Math.floor(cols / 2);
      assert.ok(solvable(createBoard(rows, cols, cats, sr, sc), sr, sc), `${rows}x${cols}`);
    }
});

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
