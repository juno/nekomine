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

// 六角形の盤面。奇数行を右に半マスずらして並べるので、隣の列は行の偶奇で変わる
const neighbors = (b, r, c) =>
  (r % 2 ? [[0, -1], [0, 1], [-1, 0], [-1, 1], [1, 0], [1, 1]] : [[0, -1], [0, 1], [-1, -1], [-1, 0], [1, -1], [1, 0]])
    .map(([dr, dc]) => [r + dr, c + dc])
    .filter(([rr, cc]) => rr >= 0 && rr < b.rows && cc >= 0 && cc < b.cols);

// 最初に押したマス (sr, sc) とその隣には猫を置かない
function randomBoard(rows, cols, cats, sr, sc) {
  const b = { rows, cols, cells: [] };
  for (let r = 0; r < rows; r++)
    b.cells.push(Array.from({ length: cols }, () => ({ cat: false, open: false, flag: false, n: 0 })));
  const safe = new Set([[sr, sc], ...neighbors(b, sr, sc)].map(([r, c]) => r * cols + c));
  const spots = [];
  for (let r = 0; r < rows; r++)
    for (let c = 0; c < cols; c++) if (!safe.has(r * cols + c)) spots.push([r, c]);
  for (let i = 0; i < cats; i++) {
    const j = i + Math.floor(Math.random() * (spots.length - i));
    [spots[i], spots[j]] = [spots[j], spots[i]];
    const [r, c] = spots[i];
    b.cells[r][c].cat = true;
    b.cells[r][c].breed = pickBreed();
    for (const [rr, cc] of neighbors(b, r, c)) b.cells[rr][cc].n++;
  }
  return b;
}

// 運に頼らない盤面: 推理だけで解けるものが出るまで作り直す
function createBoard(rows, cols, cats, sr, sc) {
  for (let i = 0; i < 5000; i++) {
    const b = randomBoard(rows, cols, cats, sr, sc);
    if (solvable(b, sr, sc)) return b;
  }
  throw new Error('盤面を生成できません。もう一度お試しください');
}

// (sr, sc) から開けて、数字と猫の総数からの推理だけで猫以外を全部開けられるか。盤面は書き換えない
function solvable(b, sr, sc) {
  const { cols } = b;
  const cell = (k) => b.cells[Math.floor(k / cols)][k % cols];
  const around = (k) => neighbors(b, Math.floor(k / cols), k % cols).map(([r, c]) => r * cols + c);
  const total = b.cells.flat().filter((c) => c.cat).length;
  const state = new Array(b.rows * cols).fill(0); // 0: 未確定, 1: 開いた, 2: 猫と確定
  const open = (k) => {
    const stack = [k];
    while (stack.length) {
      const x = stack.pop();
      if (state[x]) continue;
      state[x] = 1;
      if (cell(x).n === 0) stack.push(...around(x));
    }
  };
  // cells の中に猫がちょうど mines 匹いるとき、全部猫か全部安全なら確定させる
  const settle = (cells, mines) => {
    if (!cells.length || (mines && mines !== cells.length)) return false;
    for (const k of cells) mines ? (state[k] = 2) : open(k);
    return true;
  };

  open(sr * cols + sc);
  for (;;) {
    const unknown = [];
    state.forEach((s, k) => s || unknown.push(k));
    if (!unknown.length) return true;
    const cons = [{ cells: unknown, mines: total - state.filter((s) => s === 2).length }];
    state.forEach((s, k) => {
      if (s !== 1 || !cell(k).n) return;
      const ks = around(k);
      const cells = ks.filter((x) => !state[x]);
      if (cells.length) cons.push({ cells, mines: cell(k).n - ks.filter((x) => state[x] === 2).length });
    });
    let progress = false;
    for (const c of cons) progress = settle(c.cells, c.mines) || progress;
    if (progress) continue;
    // A が B に含まれるなら、B から A を除いた部分の猫は B.mines - A.mines 匹
    outer: for (const a of cons)
      for (const c of cons) {
        if (a === c || a.cells.length >= c.cells.length) continue;
        const inC = new Set(c.cells);
        if (!a.cells.every((k) => inC.has(k))) continue;
        const inA = new Set(a.cells);
        if (settle(c.cells.filter((k) => !inA.has(k)), c.mines - a.mines)) { progress = true; break outer; }
      }
    if (!progress) return false;
  }
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
    if (x.n === 0) stack.push(...neighbors(b, rr, cc));
  }
  return 'ok';
}

function toggleFlag(b, r, c) {
  const cell = b.cells[r][c];
  if (!cell.open) cell.flag = !cell.flag;
}

const isWon = (b) => b.cells.flat().every((c) => c.cat || c.open);

if (typeof module !== 'undefined') module.exports = { createBoard, neighbors, solvable, reveal, toggleFlag, isWon, BREEDS, pickBreed, caughtCats, addToDex };
