# ねこマインスイーパー PICO-8版

HTML版の PICO-8 移植。

## 遊ぶ

PICO-8 で `load nekomine.p8` → `run`（`logic.lua` / `game.lua` を `#include` しているので、3ファイルを同じ場所に置くこと）。

- 十字キー: カーソル移動 / O(Z): めくる / X: 毛布 / マウス: 左クリックでめくる・右クリックで毛布
- タイトルで 上下: 難易度、O: 開始、X: ねこ図鑑
- ポーズメニュー: タイトルへ戻る、音の ON/OFF
- ベストタイム・図鑑・音設定は `cartdata` で保存

## PICO-8 なしで試す（簡易プレビュー）

```
node pico8/build_preview.js   # pico8/preview.html を生成
open pico8/preview.html       # ブラウザで開く（fengari-web を CDN から読むのでネット接続が必要）
```

`game.lua` をそのまま JS 製 Lua で動かす簡易エミュレータ。フォント・音・描画の細部は実機と違う。ロジックやソースを変えたらビルドし直す。

## HTML版との違い

- 画面が 128x128 なので盤面は 9x9/10・12x12/26・14x14/36（HTML版の大きい盤面は載らない）
- PICO-8 に日本語フォントが無いので表示はローマ字/英語
- 猫の絵はスプライトではなくコードで描画（8種類は色と模様の違いのみ）
- 呼吸アニメ・SVG の細かい表情は省略

## テスト

ロジック(`logic.lua`)の単体テストと、API をスタブにした `game.lua` のスモークテストを fengari(JS 製 Lua)で実行:

```
npm i fengari  # どこか別の場所に
NODE_PATH=<その node_modules> node pico8/run_tests.js
```

PICO-8 本体での実機確認は未実施。
