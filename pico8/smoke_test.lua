-- PICO-8 API stubs: draw calls are no-ops, input is scripted
local btn, mouse, drawn = {}, {x = 0, y = 0, b = 0}, 0
for _, f in ipairs({"cls","print","line","circfill","circ","rect","rectfill","pset","sfx","poke","menuitem"}) do
  _G[f] = function() drawn = drawn + 1 end
end
local save = {}
function cartdata() end
function dget(i) return save[i] or 0 end
function dset(i, v) save[i] = v end
function btnp(i) local v = btn[i] btn[i] = false return v end
function stat(i) return i == 32 and mouse.x or i == 33 and mouse.y or i == 34 and mouse.b or 0 end
local clock = 0
function time() return clock end
cocreate, coresume, costatus, yield = coroutine.create, coroutine.resume, coroutine.status, coroutine.yield
function min(a, b) return math.min(a, b) end
function max(a, b) return math.max(a, b) end
abs, sqrt, band = math.abs, math.sqrt, function(a, b) return a & b end
function unpack(t) return table.unpack(t) end
function sub(s, i, j) return string.sub(s, i, j) end
--[[driver]]
local function frame() clock = clock + 1 / 30 _update() _draw() end
local function press(i) btn[i] = true frame() end

_init()
for l = 1, 3 do
  lv = l; st = "title"
  press(4)                                  -- start
  assert(st == "play", "start")
  press(4)                                  -- first open builds the board
  for _ = 1, 200 do frame() if not gen then break end end
  assert(b and not gen, "board built level " .. l)
  press(5)                                  -- blanket on the cursor cell
  for _ = 1, 3 do press(0) press(3) press(4) end
  mouse.x, mouse.y = 60, 60 frame()
  mouse.b = 1 frame() mouse.b = 0 frame()   -- mouse click
  newgame() press(4)                        -- fresh board for the win path
  for _ = 1, 200 do frame() if not gen then break end end
  clock = clock + 5
  -- clear the board: open every safe cell
  for k = 1, rows * cols do if not b.cat[k] and not over then b.flag[k] = false open(k) end end
  assert(over == "win", "won level " .. l)
  assert(dget(l - 1) > 0, "best saved")
  frame()
end
press(4) assert(st == "play" and not over, "again")
st = "title" press(5) assert(st == "dex") frame() press(4) assert(st == "title")
io.write("smoke ok\n")
