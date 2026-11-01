const breedIds = ['chatora', 'saba', 'kuro', 'shiro', 'hachiware', 'mike', 'siam', 'maneki'];
const levels = ['9,9,10', '16,16,40', '16,30,99'];
const read = (key) => { try { return localStorage.getItem(key); } catch { return null; } };
const write = (key, value) => { try { localStorage.setItem(key, value); } catch {} };
let oldDex;
try { oldDex = JSON.parse(read('nekomine-dex')) || {}; } catch { oldDex = {}; }

const app = Elm.Main.init({
  node: document.getElementById('app'),
  flags: {
    seed: Math.max(1, Math.floor(Date.now() % 2147483646)),
    best: levels.map(level => Number(read('nekomine-best-' + level)) || 0),
    dex: breedIds.map(id => Number(oldDex[id]) || 0),
    muted: read('nekomine-muted') === '1',
  },
});

app.ports.save.subscribe(({ best, dex, muted }) => {
  levels.forEach((level, index) => {
    if (best[index] > 0) write('nekomine-best-' + level, best[index]);
  });
  write('nekomine-dex', JSON.stringify(Object.fromEntries(breedIds.map((id, i) => [id, dex[i] || 0]))));
  write('nekomine-muted', muted ? '1' : '0');
});

let audio;
const tone = (frequencies, duration, type = 'sine', volume = 0.2, delay = 0) => {
  audio ??= new AudioContext();
  const start = audio.currentTime + delay;
  const oscillator = audio.createOscillator();
  const gain = audio.createGain();
  oscillator.type = type;
  oscillator.frequency.setValueAtTime(frequencies[0], start);
  frequencies.slice(1).forEach((frequency, i) =>
    oscillator.frequency.exponentialRampToValueAtTime(frequency, start + duration * (i + 1) / frequencies.length));
  gain.gain.setValueAtTime(0.0001, start);
  gain.gain.linearRampToValueAtTime(volume, start + 0.01);
  gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
  oscillator.connect(gain).connect(audio.destination);
  oscillator.start(start);
  oscillator.stop(start + duration);
};
app.ports.sound.subscribe(name => {
  try {
    if (name === 'open') tone([700, 1050], 0.08);
    if (name === 'flag') { tone([784, 1047], 0.13, 'triangle', 0.24); tone([1175, 1568], 0.17, 'sine', 0.2, 0.075); navigator.vibrate?.(50); }
    if (name === 'unflag') tone([350, 480], 0.08, 'sine', 0.08);
    if (name === 'meow') tone([480, 820, 520], 0.55, 'triangle', 0.25);
    if (name === 'win') [784, 988, 1175, 1568].forEach((frequency, i) => tone([frequency, frequency * 1.01], 0.2, 'sine', 0.18, i * 0.1));
  } catch { /* AudioContext is unavailable; the game remains playable. */ }
});

const root = document.getElementById('app');
let pressTimer;
let longPressed = false;
root.addEventListener('pointerdown', event => {
  clearTimeout(pressTimer);
  longPressed = false;
  if (event.pointerType !== 'touch') return;
  const target = event.target.closest('[data-cell]');
  if (!target) return;
  const index = Number(target.dataset.cell);
  pressTimer = setTimeout(() => {
    longPressed = true;
    app.ports.flagCell.send(index);
  }, 400);
});
for (const name of ['pointerup', 'pointercancel', 'pointerleave']) {
  root.addEventListener(name, () => clearTimeout(pressTimer));
}
root.addEventListener('click', event => {
  if (!longPressed) return;
  event.preventDefault();
  event.stopPropagation();
  longPressed = false;
}, true);
