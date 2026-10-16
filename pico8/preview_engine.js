// PICO-8 API を JS で最小限に再現して game.lua を動かす簡易エミュレータ (ブラウザ/node 共用)。
// 本物の PICO-8 とはフォント・丸め・音が違う。見た目と操作感の目安用
(function (root) {
  const PAL = ['000000','1D2B53','7E2553','008751','AB5236','5F574F','C2C3C7','FFF1E8','FF004D','FFA300','FFEC27','00E436','29ADFF','83769C','FF77A8','FFCCAA']
    .map((h) => [0, 2, 4].map((i) => parseInt(h.substr(i, 2), 16)));
  // 3x5 の文字。5行 x 3ビット
  const G = {
    A:'010101111101101',B:'110101110101110',C:'011100100100011',D:'110101101101110',E:'111100110100111',
    F:'111100110100100',G:'011100101101011',H:'101101111101101',I:'111010010010111',J:'001001001101010',
    K:'101101110101101',L:'100100100100111',M:'101111111101101',N:'110101101101101',O:'010101101101010',
    P:'110101110100100',Q:'010101101111011',R:'110101110101101',S:'011100010001110',T:'111010010010010',
    U:'101101101101111',V:'101101101101010',W:'101101111111101',X:'101101010101101',Y:'101101010010010',
    Z:'111001010100111',
    0:'111101101101111',1:'010110010010111',2:'110001010100111',3:'110001010001110',4:'101101111001001',
    5:'111100110001110',6:'011100111101111',7:'111001010010010',8:'111101111101111',9:'111101111001110',
    '.':'000000000000010',':':'000010000010000','>':'100010001010100','/':'001001010100100','!':'010010010000010',
    '(':'010100100100010',')':'010001001001010','-':'000000111000000','?':'110001010000010','*':'000101010101000',
    ',':'000000000010100','+':'000010111010000','_':'000000000000111',
  };

  function createEngine(fengari, src, host) {
    const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari;
    const L = lauxlib.luaL_newstate();
    lualib.luaL_openlibs(L);
    const fb = new Uint8Array(128 * 128);
    let pen = 6;
    const n = (i, d) => (lua.lua_isnoneornil(L, i) ? d : lua.lua_tonumber(L, i));
    const fl = (i, d) => Math.floor(n(i, d));
    const col = (i) => { if (!lua.lua_isnoneornil(L, i)) pen = fl(i) & 15; return pen; };
    const pset = (x, y, c) => { if (x >= 0 && x < 128 && y >= 0 && y < 128) fb[y * 128 + x] = c; };
    const num = (v) => (Number.isInteger(v) ? lua.lua_pushinteger(L, v) : lua.lua_pushnumber(L, v));
    const reg = (name, f) => {
      lua.lua_pushjsfunction(L, () => { let r; try { r = f(); } catch (e) { console.error(name, e); throw e; } if (r === undefined) return 0; typeof r === 'boolean' ? lua.lua_pushboolean(L, r) : num(r); return 1; });
      lua.lua_setglobal(L, to_luastring(name));
    };
    reg('cls', () => { fb.fill(fl(1, 0) & 15); });
    reg('pset', () => pset(fl(1), fl(2), col(3)));
    reg('rectfill', () => {
      const [a, b, c, d] = [fl(1), fl(2), fl(3), fl(4)], k = col(5);
      for (let y = Math.min(b, d); y <= Math.max(b, d); y++) for (let x = Math.min(a, c); x <= Math.max(a, c); x++) pset(x, y, k);
    });
    reg('rect', () => {
      const [a, b, c, d] = [fl(1), fl(2), fl(3), fl(4)], k = col(5);
      for (let x = Math.min(a, c); x <= Math.max(a, c); x++) { pset(x, b, k); pset(x, d, k); }
      for (let y = Math.min(b, d); y <= Math.max(b, d); y++) { pset(a, y, k); pset(c, y, k); }
    });
    reg('line', () => {
      let [x0, y0, x1, y1] = [fl(1), fl(2), fl(3), fl(4)]; const k = col(5);
      const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
      let e = dx + dy;
      for (;;) {
        pset(x0, y0, k);
        if (x0 === x1 && y0 === y1) break;
        const e2 = 2 * e;
        if (e2 >= dy) { e += dy; x0 += sx; }
        if (e2 <= dx) { e += dx; y0 += sy; }
      }
    });
    reg('circfill', () => {
      const [x, y, r] = [fl(1), fl(2), fl(3, 4)], k = col(4);
      for (let dy = -r; dy <= r; dy++) { const w = Math.floor(Math.sqrt(r * r - dy * dy) + 0.5); for (let dx = -w; dx <= w; dx++) pset(x + dx, y + dy, k); }
    });
    reg('circ', () => {
      const [x, y, r] = [fl(1), fl(2), fl(3, 4)], k = col(4);
      for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) if (Math.abs(Math.hypot(dx, dy) - r) < 0.5) pset(x + dx, y + dy, k);
    });
    reg('print', () => {
      lauxlib.luaL_tolstring(L, 1);
      const s = to_jsstring(lua.lua_tostring(L, -1)).toUpperCase(), x0 = fl(2, 0), y0 = fl(3, 0), k = col(4);
      [...s].forEach((ch, i) => {
        const g = G[ch]; if (!g) return;
        for (let j = 0; j < 15; j++) if (g[j] === '1') pset(x0 + i * 4 + (j % 3), y0 + Math.floor(j / 3), k);
      });
    });
    reg('btnp', () => host.btnp(fl(1)));
    reg('stat', () => host.stat(fl(1)));
    reg('time', () => host.time());
    reg('sfx', () => host.sfx(fl(1)));
    reg('dget', () => host.dget(fl(1)));
    reg('dset', () => host.dset(fl(1), n(2, 0)));
    for (const f of ['cartdata', 'poke']) reg(f, () => {});
    const run = (code) => {
      if (lauxlib.luaL_dostring(L, to_luastring(code)) !== 0) throw new Error(lua.lua_tojsstring(L, -1));
    };
    run(`
      flr,min,max,abs,sqrt,sub,tostr,unpack = math.floor,math.min,math.max,math.abs,math.sqrt,string.sub,tostring,table.unpack
      cocreate,coresume,costatus,yield = coroutine.create,coroutine.resume,coroutine.status,coroutine.yield
      function band(a,b) return flr(a) & flr(b) end
      function add(t,v) t[#t+1]=v return v end
      function all(t) local i=0 return function() i=i+1 return t[i] end end
      function rnd(x) return math.random()*(x or 1) end
      __menu={}
      function menuitem(i,l,f) __menu[i]=f end
      function __menucall(i) local f=__menu[i] if f then f() end end
    `);
    const p8 = (t) => t.replace(/!=/g, '~=').replace(/\b([a-z]\w*)\+=/g, '$1=$1+');
    run(src.logic); run(p8(src.game)); run('_init()');
    const call = (name) => {
      lua.lua_getglobal(L, to_luastring(name));
      if (lua.lua_pcall(L, 0, 0, 0) !== 0) throw new Error(name + ': ' + to_jsstring(lauxlib.luaL_tolstring(L, -1)));
    };
    return { fb, PAL, frame() { call('_update'); call('_draw'); }, menu: (i) => run(`__menucall(${i})`) };
  }
  const api = { createEngine, PAL };
  if (typeof module !== 'undefined') module.exports = api; else root.P8 = api;
})(this);
