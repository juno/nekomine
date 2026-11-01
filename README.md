# ねこマインスイーパー

HTML版はElmで実装しています。`index.html` をブラウザで開くと遊べます。以前のJavaScript版は `legacy.html` に残しています。

## HTML版の開発

Elm 0.19.3 と Node.js を使用します。Elmのコードを変更したら、配布用の `elm.js` を再生成してください。

```sh
elm make src/Main.elm --output=elm.js
node --test tests/game.test.js logic.test.js
```

ゲーム本体と推理可能な盤面の生成は `src/Game.elm`、画面と状態管理は `src/Main.elm` にあります。`app.js` は効果音、端末内の記録、スマホの長押しをブラウザへ接続します。ベストタイム・猫図鑑・音設定は旧HTML版の記録を引き継ぎます。

## PICO-8版

`pico8/` に PICO-8 への移植があります。遊び方・HTML版との違い・テストは [pico8/README.md](pico8/README.md) を参照。PICO-8 がなくても `node pico8/build_preview.js` で作る `pico8/preview.html` をブラウザで開けば試せます。
