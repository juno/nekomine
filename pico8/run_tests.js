// PICO-8 の Lua ロジックを fengari (JS 製 Lua 5.3) で検証する。
// 使い方: NODE_PATH=<fengari の node_modules> node pico8/run_tests.js
const { lua, lauxlib, lualib, to_luastring } = require('fengari');
const fs = require('fs');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
// PICO-8 の組み込み関数のうちロジックが使うものだけ
const shim = `
flr=math.floor; sub=string.sub
function add(t,v) t[#t+1]=v return v end
function all(t) local i=0 return function() i=i+1 return t[i] end end
function rnd(x) return math.random()*(x or 1) end
`;
const src = (f) => fs.readFileSync(__dirname + '/' + f, 'utf8');
// ゲーム側 (game.lua) は PICO-8 方言 (!=, +=) を標準 Lua に直して、API スタブでスモーク実行する
const p8 = (t) => t.replace(/!=/g, '~=').replace(/\b([a-z]\w*)\+=/g, '$1=$1+');
const code = shim + src('logic.lua') + '\n' + src('logic_test.lua') + '\n' + src('smoke_test.lua').split('--[[driver]]')[0] + p8(src('game.lua')) + '\n' + src('smoke_test.lua').split('--[[driver]]')[1];
if (lauxlib.luaL_dostring(L, to_luastring(code)) !== 0) {
  console.error(lua.lua_tojsstring(L, -1));
  process.exit(1);
}
