-- game logic. a cell is numbered k = r*cols + c + 1 (1-based)
-- kept plain-Lua compatible so run_tests.js can test it; the cart #includes it

-- spawn weights: chatora saba kuro shiro hachiware mike siam maneki
BREEDW = {30, 20, 15, 15, 10, 6, 3, 1}

function pickbreed(r)
  local x = r * 100
  for i = 1, #BREEDW do
    x = x - BREEDW[i]
    if x < 0 then return i end
  end
  return #BREEDW
end

-- hex grid: odd rows (0-based) shift half a cell right, so neighbors depend on row parity
function neighbors(b, k)
  local cols = b.cols
  local r, c = flr((k - 1) / cols), (k - 1) % cols
  local d = r % 2 == 1
    and {{0,-1},{0,1},{-1,0},{-1,1},{1,0},{1,1}}
    or {{0,-1},{0,1},{-1,-1},{-1,0},{1,-1},{1,0}}
  local o = {}
  for i = 1, 6 do
    local rr, cc = r + d[i][1], c + d[i][2]
    if rr >= 0 and rr < b.rows and cc >= 0 and cc < cols then o[#o + 1] = rr * cols + cc + 1 end
  end
  return o
end

-- no cats on the first cell sk or its neighbors
function genboard(rows, cols, cats, sk)
  local n = rows * cols
  local b = {rows = rows, cols = cols, cat = {}, n = {}, open = {}, flag = {}, breed = {}}
  for k = 1, n do b.cat[k] = false b.n[k] = 0 b.open[k] = false b.flag[k] = false end
  local safe = {[sk] = true}
  for k in all(neighbors(b, sk)) do safe[k] = true end
  local spots = {}
  for k = 1, n do if not safe[k] then spots[#spots + 1] = k end end
  for i = 1, cats do
    local j = i + flr(rnd(#spots - i + 1))
    spots[i], spots[j] = spots[j], spots[i]
    local k = spots[i]
    b.cat[k] = true
    b.breed[k] = pickbreed(rnd())
    for m in all(neighbors(b, k)) do b.n[m] = b.n[m] + 1 end
  end
  return b
end

-- can everything but cats be opened by pure deduction from sk? does not modify b
function solvable(b, sk)
  local n, total = b.rows * b.cols, 0
  for k = 1, n do if b.cat[k] then total = total + 1 end end
  local st = {} -- 0 unknown, 1 open, 2 known cat
  for k = 1, n do st[k] = 0 end
  local function open(k)
    local stack = {k}
    while #stack > 0 do
      local x = stack[#stack]
      stack[#stack] = nil
      if st[x] == 0 then
        st[x] = 1
        if b.n[x] == 0 then for m in all(neighbors(b, x)) do stack[#stack + 1] = m end end
      end
    end
  end
  -- cells hold exactly mines cats: if all cats or all safe, settle them
  local function settle(cells, mines)
    if #cells == 0 or (mines ~= 0 and mines ~= #cells) then return false end
    for k in all(cells) do if mines ~= 0 then st[k] = 2 else open(k) end end
    return true
  end

  open(sk)
  while true do
    local unknown, found = {}, 0
    for k = 1, n do
      if st[k] == 0 then unknown[#unknown + 1] = k elseif st[k] == 2 then found = found + 1 end
    end
    if #unknown == 0 then return true end
    local cons = {{cells = unknown, mines = total - found}}
    for k = 1, n do
      if st[k] == 1 and b.n[k] > 0 then
        local cells, mines = {}, b.n[k]
        for m in all(neighbors(b, k)) do
          if st[m] == 0 then cells[#cells + 1] = m elseif st[m] == 2 then mines = mines - 1 end
        end
        if #cells > 0 then cons[#cons + 1] = {cells = cells, mines = mines} end
      end
    end
    local progress = false
    for c in all(cons) do if settle(c.cells, c.mines) then progress = true end end
    if not progress then
      -- if A is inside B, B minus A holds B.mines - A.mines cats
      for a in all(cons) do
        for c in all(cons) do
          if not progress and a ~= c and #a.cells < #c.cells then
            local ina, inc, sub = {}, {}, {}
            for k in all(a.cells) do ina[k] = true end
            for k in all(c.cells) do inc[k] = true end
            local ok = true
            for k in all(a.cells) do if not inc[k] then ok = false end end
            if ok then
              for k in all(c.cells) do if not ina[k] then sub[#sub + 1] = k end end
              progress = settle(sub, c.mines - a.mines)
            end
          end
        end
      end
    end
    if not progress then return false end
  end
end

-- no-guess board: regenerate until deduction alone solves it.
-- tick runs after each retry (the cart yields there); returns nil on failure
function createboard(rows, cols, cats, sk, tick)
  for _ = 1, 5000 do
    local b = genboard(rows, cols, cats, sk)
    if solvable(b, sk) then return b end
    if tick then tick() end
  end
end

function reveal(b, k)
  if b.open[k] or b.flag[k] then return "ok" end
  if b.cat[k] then b.open[k] = true return "boom" end
  local stack = {k}
  while #stack > 0 do
    local x = stack[#stack]
    stack[#stack] = nil
    if not (b.open[x] or b.flag[x]) then
      b.open[x] = true
      if b.n[x] == 0 then for m in all(neighbors(b, x)) do stack[#stack + 1] = m end end
    end
  end
  return "ok"
end

function toggleflag(b, k)
  if not b.open[k] then b.flag[k] = not b.flag[k] end
end

function iswon(b)
  for k = 1, b.rows * b.cols do if not (b.cat[k] or b.open[k]) then return false end end
  return true
end

-- win: every cat; lose: only flagged cats. returns breed numbers
function caught(b, won)
  local o = {}
  for k = 1, b.rows * b.cols do
    if b.cat[k] and (won or b.flag[k]) then o[#o + 1] = b.breed[k] end
  end
  return o
end
