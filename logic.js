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

if (typeof module !== 'undefined') module.exports = { createBoard, reveal, toggleFlag, isWon };
