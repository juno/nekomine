// weight が大きいほど出やすい。見た目は index.html の BREED_LOOK
const BREEDS = [
  { id: 'chatora', name: '茶トラ', weight: 30 },
  { id: 'saba', name: 'サバトラ', weight: 20 },
  { id: 'kuro', name: '黒猫', weight: 15 },
  { id: 'shiro', name: '白猫', weight: 15 },
  { id: 'hachiware', name: 'ハチワレ', weight: 10 },
  { id: 'mike', name: '三毛', weight: 6 },
  { id: 'siam', name: 'シャム', weight: 3 },
  { id: 'maneki', name: '招き猫', weight: 1 },
];

function pickBreed(rand = Math.random()) {
  let x = rand * BREEDS.reduce((s, b) => s + b.weight, 0);
  for (const b of BREEDS) if ((x -= b.weight) < 0) return b.id;
  return BREEDS[BREEDS.length - 1].id;
}

// クリアなら盤面の猫全部、負けなら正しく目印した猫だけ
const caughtCats = (b, won) => b.cells.flat().filter((c) => c.cat && (won || c.flag)).map((c) => c.breed);

function addToDex(dex, ids) {
  const next = { ...dex };
  const fresh = [];
  for (const id of ids) {
    if (!next[id]) fresh.push(id);
    next[id] = (next[id] || 0) + 1;
  }
  return { dex: next, fresh };
}

const near = (b, r, c) => {
  const out = [];
  for (let dr = -1; dr <= 1; dr++)
    for (let dc = -1; dc <= 1; dc++) {
      const rr = r + dr, cc = c + dc;
      if ((dr || dc) && rr >= 0 && rr < b.rows && cc >= 0 && cc < b.cols) out.push([rr, cc]);
    }
  return out;
};

// 最初に押したマス (sr, sc) とその周囲には猫を置かない
function createBoard(rows, cols, cats, sr, sc) {
  const b = { rows, cols, cells: [] };
  for (let r = 0; r < rows; r++)
    b.cells.push(Array.from({ length: cols }, () => ({ cat: false, open: false, flag: false, n: 0 })));
  const spots = [];
  for (let r = 0; r < rows; r++)
    for (let c = 0; c < cols; c++) if (Math.abs(r - sr) > 1 || Math.abs(c - sc) > 1) spots.push([r, c]);
  for (let i = 0; i < cats; i++) {
    const j = i + Math.floor(Math.random() * (spots.length - i));
    [spots[i], spots[j]] = [spots[j], spots[i]];
    const [r, c] = spots[i];
    b.cells[r][c].cat = true;
    b.cells[r][c].breed = pickBreed();
    for (const [rr, cc] of near(b, r, c)) b.cells[rr][cc].n++;
  }
  return b;
}

function reveal(b, r, c) {
  const cell = b.cells[r][c];
  if (cell.open || cell.flag) return 'ok';
  if (cell.cat) return (cell.open = true), 'boom';
  const stack = [[r, c]];
  while (stack.length) {
    const [rr, cc] = stack.pop();
    const x = b.cells[rr][cc];
    if (x.open || x.flag) continue;
    x.open = true;
    if (x.n === 0) stack.push(...near(b, rr, cc));
  }
  return 'ok';
}

function toggleFlag(b, r, c) {
  const cell = b.cells[r][c];
  if (!cell.open) cell.flag = !cell.flag;
}

const isWon = (b) => b.cells.flat().every((c) => c.cat || c.open);

if (typeof module !== 'undefined') module.exports = { createBoard, reveal, toggleFlag, isWon, BREEDS, pickBreed, caughtCats, addToDex };
