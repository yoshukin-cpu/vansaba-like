# 実装計画 v1.1

> 前提: SPEC.md v1.1 / Godot 4.7.2 / v1.0 実装済み (P0〜P7 完了・スプライト差し替え済み)。
> v1.1 は `IDEA.md`「バージョンアップ案1」(地面の描画 / 宝箱とアイテム) の実装計画。
> 方針: データ駆動・仮素材・小さく動くものを反復。Editor toolsで構築、Runtime toolsで検証。

## 0. ゴール・マイルストーン

### v1.0 (完了)

- M1 移動+カメラで歩ける (P0) ✅
- M2 武器で敵を倒してXPが出る (P1-P2) ✅
- M3 レベルアップ3択ループが回る (P3) ✅
- M4 10分波形+10敵+20カードが揃う (P4) ✅
- M5 ボス2体+勝敗が付く (P5) ✅
- M6 300体でも60fps近く保つ (P6-P7) ✅

### v1.1 (新規)

- **M7 周期的に広がる草原マップを歩ける (P8)**
- **M8 木・岩の裏に隠れる (Yソートが正しい) (P9)**
- **M9 草原と荒野が素材で描画される (P10)**
- **M10 宝箱を開けて9種の中身が出る (P11)**
- **M11 宝箱込みで10分通しプレイが成立し、60fpsを維持 (P12)**

## 1. ファイル構成 (v1.1)

```
res://
  main.tscn (Main: y_sort_enabled=true, Ground + Obstacles + 各マネージャ)
  project.godot (input追加, stretch設定, layer 6=Obstacle)
  world/world_map.gd, world/chunk_gen.gd, world/hash_noise.gd, world/tileset.tres
  objects/chest.tscn, objects/chest.gd, objects/bomb.tscn, objects/bomb.gd
  systems/chest_director.gd, data/items_db.gd
  player/player.tscn, player.gd          # buffs 追加, mask に layer 6
  enemies/enemy.tscn, enemy.gd           # mask に layer 6, スタック検知
  weapons/weapon_base.gd                 # オートエイムに chests 追加, バフ倍率
  ui/hud.tscn (SCORE), ui/result_ui.gd (スコア行)
  tools/build_tileset.gd, tools/verify_world.gd, tools/verify_chests.gd
```

## 2. フェーズ計画 (v1.1)

### P8 マップ基盤 [M7] ✅ 完了

- 実装: `world/hash_noise.gd` / `world/chunk_gen.gd` / `world/tileset_builder.gd` / `world/world_map.gd`
- 実測: 生成 0.94 ms/チャンク (LUT 110ms は起動時1回) / 荒野 18.6% / 障害物 2.61% / 実機 60fps
- 検証: `tools/verify_world.gd` (周期性・密度・生成速度) — PASS

- `world/hash_noise.gd`: 周期対応のハッシュ/値ノイズ (static)
- `world/chunk_gen.gd`: チャンクデータ (バイオーム・装飾・障害物セル) を返す純関数。周期 288タイル対応
- `world/world_map.gd`: アクティブ窓 5×5チャンクの差分更新、`Ground` TileMapLayer へのセル配置、rebase 安全弁
- 仮タイル: 単色 (草原=緑 / 荒野=茶 / 砂利=灰) の TileSet を先に作り、素材は P10
- `Main/Background` と `systems/grid_background.gd` を削除。`Ground` は z_index = -10
- **完了条件**: ゲームを開始して歩き回ると、草原と荒野が途切れず続く。1分歩くと見覚えのある地形に戻る
- 検証: `tools/verify_world.gd` (ヘッドレス) で「`gen(cx,cy) == gen(cx+9,cy+9)`」「同一セルのハッシュが一致」を assert + 実機キャプチャで見た目確認

### P9 障害物とYソート [M8] ✅ 完了

- 実装: layer 6 (Obstacle) / Main の y_sort / プール4ノードの Node2D 化 / スタック検知 / 湧き回避
- 実測: 木の幹で停止 (x=284.16/理論282)、Yソート境界 y=28 (予測一致)、木の裏で隠れる
- 検証: `tools/verify_obstacles.gd` / `tools/verify_obstacle_block.gd` / `tools/verify_terrain.gd` — PASS
- 判明した落とし穴: **衝突ポリゴンはセル中心基準** (セル左上基準で指定すると (24,24) ずれて全部すり抜ける)

- `Obstacles` TileMapLayer を追加 (y_sort_enabled = true, layer 6 = Obstacle)
- `project.godot` に layer 6 を追加。`player.tscn` / `enemy.tscn` の mask に 64 を追加 (ボス・弾は入れない)
- プール4ノード (`PoolShots` / `PoolHoming` / `PoolEnemyShots` / `PoolGems`) を `Node` → `Node2D` + y_sort_enabled = true に変更
- `Main` に y_sort_enabled = true。`CombatFx` は z_index = 5 で前面固定
- 木タイルの `texture_origin` / `y_sort_origin` を実測で確定 (スパイク: 最小シーン + スクショ)
- スポーン位置の障害物回避 (`spawn_director`)、敵のスタック検知 (§18.5)
- **完了条件**: 木の裏に回ると主人公・敵・弾が隠れ、木の前では隠れない。木に当たって止まる
- 検証: 木の上/下/左/右にプレイヤーを置いて `capture_frames` で4枚撮影 → vision で遮蔽の向きを確認。`verify_world.gd` に障害物セル回避の assert を追加

### P10 タイル素材 [M9] ✅ 完了

- 実装: 1min-image (gpt-image-2 / quality low) で3シート生成 → `world/sprites/raw/process_tiles.py` → `world/sprites/ground_0..17.png`, `ob_0..4.png`, `objects/sprites/*.png`
- 加工の勘所: セル縁のグリッド線を内側に切る / 装飾タイルの下地色を草原の基準色に寄せる / クロマキーは外周連結成分のみ
- 検証: `tmp_shots/preview_ground.png`・`preview_props.png` を vision 確認、実機キャプチャで破綻なし

- 1min-image (gpt-image-2, quality low) で生成: (1) 地面タイル (草原4+荒野4+砂利4+装飾6) 1シート、(2) 木3種 1シート、(3) 岩2種 + 宝箱 (閉/開) + 爆弾 1シート
- クロマキー処理 → 48px グリッド整列 (`player/sprites/raw/process_sheet.py` を流用)
- `tools/build_tileset.gd` (ヘッドレス) で `world/tileset.tres` を生成 (物理形状・y_sort_origin・texture_origin 込み)
- 生成後は vision で検査 (タイルの継ぎ目・木の根元の位置・宝箱の向き)
- **完了条件**: 草原に荒野がまだらに広がり、木と岩が自然に立っている (単色タイルが消えている)
- 検証: 実機キャプチャ (4方向 + 荒野/木の密集地) を vision で確認。タイル継ぎ目の破綻がないこと

### P11 宝箱とアイテム [M10] ✅ 完了

- 実装: `objects/chest.tscn` + `chest.gd` (layer 2 受信用Area2D / HP1 / 寿命30秒+点滅 / 開封0.5秒表示) /
  `objects/bomb.tscn` + `bomb.gd` (2.5秒ヒューズ+警告円 / 爆発200dmg・半径140 / 破片12発・各40dmg・射程400・貫通) /
  `systems/chest_director.gd` (15秒間隔・初回30秒・ラッシュ5秒 / リング320〜540+画面内 / 障害物回避 / 上限4) /
  `data/items_db.gd` (9種+レア5%) / `player.gd` にバフ4種 / HUD SCORE / リザルトにスコア行 / SE 6種追加
- SPEC §19.2 からの実装差分: オービットボムの爆発はグループ走査のため `projectiles/bomb.gd` に chests 走査を1箇所追加
  (直線弾・スピン・ホーミングは Area2D 検出のため変更なし)。チェインライトニングは敵専用のまま
  (`find_nearest_enemy` に `with_chests` 引数を追加し、通常エイムとボム照準だけ true)。
- **完了条件**: 15秒ごとに宝箱が現れ、攻撃すると開いて中身が出る。9種すべてが機能する → 達成
- 検証: `tools/verify_chests.gd` (32件 ALL PASS: 抽選分布・全アイテム効果・開封フロー・爆弾・オートエイム) +
  `tools/verify_chest_look.gd` (開閉・ヒューズ・爆発の実機キャプチャ、画素で確認)。回帰: `test_gem_magnet.gd` ALL PASS

- `objects/chest.tscn` + `chest.gd`: layer 2 の受信用 Area2D、`take_damage()`、HP1、寿命30秒、点滅
- `systems/chest_director.gd`: 15秒間隔の出現 (初回30秒)、リング上の位置決め + 障害物回避、同時上限4、ラッシュ対応
- `data/items_db.gd`: 9種 + レア枠の重みテーブル
- 中身の実装: 回復 / コイン (スコア) / 爆弾 / 敵 / XP散布 / 一時強化 / 全ジェム回収 / 宝箱ラッシュ / 武器Lv+1
- `objects/bomb.tscn`: 2.5秒ヒューズ + 警告円 + 爆発 (200dmg/半径140) + 破片弾12発
- `player.gd` に `buffs` (攻撃/CD/移動/無敵の倍率)、`weapon_base.gd` の読み出しに反映
- HUD に SCORE、リザルトにスコア行
- SE: 宝箱出現・開封・ヒューズ・爆発・コイン (`audio_manager._tone` に追加)
- **完了条件**: 15秒ごとに宝箱が現れ、攻撃すると開いて中身が出る。9種すべてが機能する
- 検証: `tools/verify_chests.gd` (ヘッドレス) で各アイテムを強制排出し、HP/スコア/敵数/バフ/ジェム数の変化を assert。実機で開封→爆発のスクショ

### P12 調整・QA [M11]

- 通しプレイ (0→10分、倍速script併用) で宝箱込みのバランスを計測 → §20.1 の順で調整 (cap +10〜15% など)
- パフォーマンス計測: 地面25,600セル + 障害物 + 敵250体 + 弾/ジェムで60fps。チャンク跨ぎのヒッチ確認
- 障害物の詰まり・弾の遮蔽・Yソートの破綻がないか全敵種で確認 (ボス2体は障害物を無視して突進すること)
- SPECとの差分を修正、決定事項チェックリスト (D1〜D16) の承認結果を反映
- **完了条件**: 10分プレイが最後まで破綻なく動き、宝箱込みで「易しすぎない」難易度になっている
- 検証: `run_test_scenario` / `run_stress_test` + 通しプレイのスクショ・ログ

## 3. 並行可能タスク

- P10 (素材生成) は P8/P9 と並行可 (仮タイルで先にロジックを通すため)
- `data/items_db.gd` と UI (SCORE / リザルト) は P11 の他作業と並行可
- SE 追加は P11 の最後にまとめて (差し替え可能なためブロッカーにしない)

## 4. リスク・対策 (v1.1 追加分)

| リスク | 対策 |
|---|---|
| チャンク生成でヒッチ | 窓を 5×5 にして差分更新。1チャンク<3ms を計測し、超えるなら窓を 3×3 に縮小 |
| Yソートが効かない/順序が逆 | P9 の最初に最小シーンでスパイク (スクショ比較)。`y_sort_origin` の符号を実測で確定 |
| 障害物で敵が詰まる | スタック検知 (§18.5) + 湧き位置の障害物回避。ボスと弾は非衝突 |
| タイル素材の継ぎ目が汚い | バリアント4種 + 砂利境界。生成後 vision で検査し、破綻したら再生成 (既存を上書きしない) |
| 宝箱でヌルゲー化 | P12 で計測して cap/回復量を調整 (数値を先に決めない) |
| 座標が16bitセル範囲を超える | rebase 安全弁 (|cell| > 10000 で周期ぶんずらして再配置) |
| scope肥大 | v1.1対象外 (autotile・ミニマップ・リロール・障害物破壊) は入れない |

## 5. 検証コマンド

- 構築: `create_scene`, `batch_add_nodes`, `create_script`, `attach_script`, `save_scene`
- 実行: `play_scene` → `simulate_key/mouse_click/action` → `get_game_screenshot/capture_frames/monitor_properties/assert_node_state` → `stop_scene`
- 調査: `get_scene_tree`, `read_script`, `get_editor_errors`, `get_output_log`
- ヘッドレス (MCP経由が不安定なとき): `godot --headless --path <proj> --script res://tools/verify_*.gd`
- 注意: ヘッドレス起動で `project.godot` の `[autoload]` が落ちることがある → コミット前に `git checkout -- project.godot`

## 6. 次アクション提案

1. SPEC.md §22 の決定事項チェックリスト (D1〜D16) を確認・承認する
2. 承認後 P8 から実装 (仮タイルでマップ基盤 → 障害物 → 素材 → 宝箱 → 調整)
3. 実装ブロッカーは D1 (世界の形)・D6/D7 (障害物の実装と衝突)・D9/D10 (宝箱の出現と開封) — ここが決まれば P9 以降は並行して進められる
