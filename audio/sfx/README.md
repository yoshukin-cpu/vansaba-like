# 効果音 (ElevenLabs 生成)

格納先: `audio/sfx/`。ファイル名 = `audio_manager.gd` のキーと一致させる
(置換時は `_tone(...)` を `load("res://audio/sfx/<キー>.wav")` に変えるだけ)。

## 構成

- 既存 17音の置換 (`shoot`〜`beep`)。ただし `hit` は現状どのコードからも
  呼ばれていない (将来の武器用に予備として生成)。
- 新規 3音: `item_pickup` / `chest_open` / `gem` (D27 のメモに対応。
  `countdown`=`beep`、`fanfare`=`clear` で代用するため追加なし)。

## 生成一覧

| # | ファイル名 | 用途 (再生箇所) | 長さ | 生成プロンプト (EN) |
|---|-----------|----------------|------|---------------------|
| 1 | shoot.wav | 武器の発射 (`weapon_base`) | 0.15s | Quick retro laser shot, sharp downward zap, 8-bit arcade, dry, no reverb |
| 2 | zap.wav | チェインライトニングの発射 | 0.15s | Crackling electricity arc burst, high-voltage sizzle snap, dry |
| 3 | hit.wav | 命中・汎用 (予備。現状未使用) | 0.12s | Short impact thwack, punch hitting armor, tight and punchy, dry |
| 4 | kill.wav | 敵の撃破 (`enemy`) | 0.25s | Small monster pop defeat, cartoonish squash burst with downward pitch, dry |
| 5 | hurt.wav | 主人公の被弾 (`player`) | 0.30s | Player damage grunt thud, heavy low thump with brief distortion, dry |
| 6 | explode.wav | 爆弾の爆発 (`bomb`) | 0.80s | Chunky 16-bit explosion, deep boom with debris crackle tail, no reverb |
| 7 | levelup.wav | レベルアップ (`main`) | 0.60s | Bright ascending arpeggio chime, three rising notes, retro RPG level up, dry |
| 8 | ui.wav | UI の選択・決定 (`main`) | 0.08s | Tiny UI click blip, high short tick, dry |
| 9 | warn.wav | ボス接近の警告 (`main`) | 0.60s | Ominous low warning horn swell, boss alert, tense, slight echo |
| 10 | clear.wav | クリアのファンファーレ (`main`) | 1.50s | Triumphant retro fanfare flourish, rising major-key jingle, 16-bit victory |
| 11 | death.wav | ゲームオーバー (`main`) | 1.20s | Somber descending game-over drone, dark low synth fall, slow fade |
| 12 | pop.wav | 出現・設置の軽い音 (`chest_director`・爆弾) | 0.15s | Soft popping cork burst, small spawn appear effect, dry |
| 13 | chest.wav | 宝箱の出現ジングル (`chest_director`) | 0.30s | Wooden treasure chest creak open with metallic latch clink, dry |
| 14 | chest_open.wav | 宝箱の開封 (新規) | 0.50s | Magical treasure reveal sparkle, shimmering rising glint cascade, dry |
| 15 | coin.wav | コイン・スコア取得 (`chest_director`) | 0.25s | Bright coin ding, classic two-tone arcade coin pickup, dry |
| 16 | gem.wav | 経験値ジェムの取得 (新規) | 0.15s | Delicate crystal ting pickup, tiny glassy ping, dry |
| 17 | item_pickup.wav | アイテムの取得 (新規) | 0.30s | Pleasant item grab chime, quick rising pluck with sparkle, dry |
| 18 | buff.wav | 一時強化の付与 (`chest_director`) | 0.40s | Power-up surge whoosh rising, energizing shimmer swell, dry |
| 19 | heal.wav | 回復 (`chest_director`) | 0.40s | Warm healing glow chime, soft bell wash ascending, calm, dry |
| 20 | beep.wav | クリア countdown (`main`) | 0.10s | Clean countdown beep, single pure sine tick, dry |

## 生成時の注意 (ElevenLabs プロンプトガイドの原則を応用)

- 1音1イベントに絞る (簡潔・具体的に)。音声・音楽の混入禁止を明示する
  (`dry, no reverb` 等で余計な残響を抑える)。
- 長さは上の表のとおり duration に指定する (SE は短いほど応答が良い)。
- 出力は 44.1kHz / 16bit / mono の wav に変換して格納する。例:
  `ffmpeg -i in.mp3 -ar 44100 -ac 1 -sample_fmt s16 out.wav`

## 組み込み (実装時に行う)

1. wav をこのフォルダに置く (ファイル名は上の表どおり)。
2. `systems/audio_manager.gd` の `_tone(...)` を
   `load("res://audio/sfx/<キー>.wav")` に置換する。
3. `tools/` の verify (特に `verify_chests`・`verify_v12`) で回帰する。
   音量は `players` の `-10.0dB` で統一済みのため、生成音のラウドネス差が
   大きい場合のみ個別調整する。
