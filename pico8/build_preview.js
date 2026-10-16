// preview.html を生成する: node pico8/build_preview.js (fengari-web は CDN から読むのでネット接続が必要)
const fs = require('fs');
const d = __dirname + '/';
const rd = (f) => fs.readFileSync(d + f, 'utf8');
const sfx = rd('nekomine.p8').split('__sfx__\n')[1].trim().split('\n');
const html = `<!doctype html>
<html lang="ja"><head><meta charset="utf-8"><title>ねこマインスイーパー PICO-8 プレビュー</title>
<style>
  body { background:#222; color:#ddd; font:14px/1.6 sans-serif; display:flex; flex-direction:column; align-items:center; margin:0; padding:16px; }
  canvas { width:512px; height:512px; image-rendering:pixelated; background:#000; cursor:crosshair; }
  button { font:inherit; margin:6px 4px; } #err { color:#f66; white-space:pre-wrap; }
  small { color:#999; max-width:512px; }
</style></head><body>
<canvas id="c" width="128" height="128"></canvas>
<div><button onclick="eng.menu(1)">メニュー: タイトルへ</button><button onclick="eng.menu(2)">メニュー: 音 ON/OFF</button></div>
<small>十字キー: 移動 / Z: めくる / X: 毛布 / マウス: 左クリックでめくる・右クリックで毛布。簡易エミュレータなので、フォント・音・描画の細部は実機と違います。</small>
<div id="err"></div>
<script src="https://cdn.jsdelivr.net/npm/fengari-web@0.1.4/dist/fengari-web.js"></script>
<script>${rd('preview_engine.js')}</script>
<script>
const SRC = { logic: ${JSON.stringify(rd('logic.lua'))}, game: ${JSON.stringify(rd('game.lua'))} };
const SFX = ${JSON.stringify(sfx)};
const down = {}, tap = {}, held = {};
const KEYS = { ArrowLeft:0, ArrowRight:1, ArrowUp:2, ArrowDown:3, z:4, c:4, n:4, x:5, v:5, m:5 };
let mouse = { x:0, y:0, b:0 }, ac;
const cv = document.getElementById('c'), ctx = cv.getContext('2d'), img = ctx.createImageData(128, 128);
// 効果音: SFX 行 (8桁ヘッダ + 32音 x 5桁) を Web Audio で近似再生。波形は三角波固定
function sfx(n) {
  const line = SFX[n]; if (!line) return;
  ac ??= new AudioContext();
  const speed = parseInt(line.substr(2, 2), 16) / 120;
  let t = ac.currentTime, prev = null;
  for (let i = 0; i < 32; i++) {
    const s = line.substr(8 + i * 5, 5), p = parseInt(s.substr(0, 2), 16), v = parseInt(s[3], 16), e = parseInt(s[4], 16);
    if (!v) continue;
    const f = 65.41 * 2 ** (p / 12), o = ac.createOscillator(), g = ac.createGain(), at = t + i * speed;
    o.type = 'triangle';
    if (e === 1 && prev) o.frequency.setValueAtTime(prev, at), o.frequency.linearRampToValueAtTime(f, at + speed);
    else o.frequency.setValueAtTime(f, at);
    g.gain.setValueAtTime(v / 7 * 0.15, at);
    if (e === 5) g.gain.linearRampToValueAtTime(0, at + speed);
    o.connect(g).connect(ac.destination); o.start(at); o.stop(at + speed);
    prev = f;
  }
}
const t0 = performance.now(), store = {};
const host = {
  btnp: (i) => held[i] === 1 || (held[i] >= 16 && (held[i] - 16) % 4 === 0),
  stat: (i) => ({ 32: mouse.x, 33: mouse.y, 34: mouse.b, 1: 0.1 }[i] || 0),
  time: () => (performance.now() - t0) / 1000,
  sfx,
  dget: (i) => { try { return +localStorage.getItem('nekomine-p8-' + i) || 0; } catch { return store[i] || 0; } },
  dset: (i, v) => { try { localStorage.setItem('nekomine-p8-' + i, v); } catch { store[i] = v; } },
};
let eng;
try { eng = P8.createEngine(fengari, SRC, host); } catch (e) { document.getElementById('err').textContent = e.message; throw e; }
addEventListener('keydown', (e) => { const k = KEYS[e.key.toLowerCase()] ?? KEYS[e.key]; if (k === undefined) return; e.preventDefault(); down[k] = tap[k] = true; });
addEventListener('keyup', (e) => { const k = KEYS[e.key.toLowerCase()] ?? KEYS[e.key]; if (k !== undefined) down[k] = false; });
const pos = (e) => { const r = cv.getBoundingClientRect(); mouse.x = Math.floor((e.clientX - r.left) / r.width * 128); mouse.y = Math.floor((e.clientY - r.top) / r.height * 128); };
cv.addEventListener('mousemove', pos);
cv.addEventListener('mousedown', (e) => { pos(e); mouse.b |= e.button === 2 ? 2 : 1; });
addEventListener('mouseup', (e) => { mouse.b &= ~(e.button === 2 ? 2 : 1); });
cv.addEventListener('contextmenu', (e) => e.preventDefault());
setInterval(() => {
  for (let i = 0; i < 6; i++) { held[i] = down[i] || tap[i] ? (held[i] || 0) + 1 : 0; tap[i] = false; }
  try { eng.frame(); } catch (e) { document.getElementById('err').textContent = e.message; return; }
  eng.fb.forEach((c, i) => { img.data.set([...eng.PAL[c], 255], i * 4); });
  ctx.putImageData(img, 0, 0);
}, 1000 / 30);
</script></body></html>`;
fs.writeFileSync(d + 'preview.html', html);
console.log('wrote pico8/preview.html');
