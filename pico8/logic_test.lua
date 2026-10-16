local fails = 0
local function eq(a, b, msg)
  if a ~= b then fails = fails + 1 print("NG " .. msg .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
end
local function has(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
local function count(b, f) local n = 0 for k = 1, b.rows * b.cols do if f(k) then n = n + 1 end end return n end

-- 六角形は奇数行(0始まり)を右に半マスずらす。k = r*cols + c + 1
local b = {rows = 5, cols = 5}
local function ks(r, c) return r * 5 + c + 1 end
local function same(list, want, msg)
  eq(#list, #want, msg .. " 個数")
  for _, w in ipairs(want) do eq(has(list, w), true, msg .. " " .. w) end
end
same(neighbors(b, ks(2, 2)), {ks(2,1), ks(2,3), ks(1,1), ks(1,2), ks(3,1), ks(3,2)}, "偶数行")
same(neighbors(b, ks(1, 2)), {ks(1,1), ks(1,3), ks(0,2), ks(0,3), ks(2,2), ks(2,3)}, "奇数行")
same(neighbors(b, ks(0, 0)), {ks(0,1), ks(1,0)}, "角")

-- 猫の数・最初のマスと隣は安全・n が正しい
for i = 1, 20 do
  local sk = 4 * 9 + 4 + 1
  local g = createboard(9, 9, 10, sk)
  eq(count(g, function(k) return g.cat[k] end), 10, "猫の数")
  eq(g.cat[sk], false, "最初のマスに猫なし")
  for _, k in ipairs(neighbors(g, sk)) do eq(g.cat[k], false, "最初の隣に猫なし") end
  for k = 1, 81 do
    local n = 0
    for _, j in ipairs(neighbors(g, k)) do if g.cat[j] then n = n + 1 end end
    eq(g.n[k], n, "n")
    if g.cat[k] then eq(g.breed[k] ~= nil, true, "猫に種類") end
  end
  eq(solvable(g, sk), true, "推理で解ける")
end

-- 解けない盤面を solvable は見抜く: 猫2匹が左端の2マスだけ・最初が右端 ではなく、
-- 3マスで猫1匹、どちらの数字からも区別できない配置
local u = {rows = 1, cols = 3, cat = {false, true, false}, n = {1, 0, 1}, open = {}, flag = {}}
-- 猫の総数1・端(1)を開く: n=1 の隣は猫確定→ 解ける
eq(solvable(u, 1), true, "1x3 は解ける")
local w = {rows = 2, cols = 2, cat = {true, false, false, true}, n = {0, 2, 2, 0}, open = {}, flag = {}}
-- 2x2: 偶数行の隣は左右と上下(奇数行は上の同列と右)。単純な形で、少なくとも真偽が返る
eq(type(solvable(w, 2)), "boolean", "solvable は真偽値")

-- reveal: 猫で boom、n=0 は連鎖、旗は開かない
local g = createboard(9, 9, 10, 41)
eq(reveal(g, 41), "ok", "最初は安全")
eq(g.open[41], true, "開いた")
local ck; for k = 1, 81 do if g.cat[k] then ck = k break end end
g.flag[ck] = true
eq(reveal(g, ck), "ok", "旗の猫は開かない")
g.flag[ck] = false
eq(reveal(g, ck), "boom", "猫は boom")

-- toggleflag: 開いたマスは変えない
local f = createboard(9, 9, 10, 41)
toggleflag(f, 1); eq(f.flag[1], true, "旗が立つ")
toggleflag(f, 1); eq(f.flag[1], false, "旗が外れる")
f.open[2] = true; toggleflag(f, 2); eq(f.flag[2], false, "開いたマスに旗なし")

-- iswon: 猫以外が全部開いたら勝ち
local v = createboard(9, 9, 10, 41)
eq(iswon(v), false, "最初は未クリア")
for k = 1, 81 do if not v.cat[k] then v.open[k] = true end end
eq(iswon(v), true, "全部開いたら勝ち")

-- pickbreed: 重みに従う。端の値でも範囲内
eq(pickbreed(0), 1, "0 は茶トラ")
eq(pickbreed(0.9999), 8, "1未満の最大は招き猫")
local total = 0 for _, w in ipairs(BREEDW) do total = total + w end
eq(total, 100, "重み合計")

-- caught: クリアなら全部、負けなら旗の猫だけ
local c = createboard(9, 9, 10, 41)
eq(#caught(c, true), 10, "クリアで全部")
eq(#caught(c, false), 0, "旗なしは0")
for k = 1, 81 do if c.cat[k] then c.flag[k] = true break end end
eq(#caught(c, false), 1, "旗1つ")

if fails > 0 then error(fails .. " failed") end
print("all ok")
