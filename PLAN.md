# 実装計画 v1.6

> 前提: SPEC.md v1.6 / Godot 4.7.2 / v1.0〜v1.5 実装済み (P0〜P18 完了)。
> v1.1 以降は `IDEA.md` の「バージョンアップ案1〜4」を順に実装する計画として積み上げている。v1.6 = バージョンアップ案4。
> 方針: データ駆動・仮素材・小さく動くものを反復。Editor toolsで構築、Runtime toolsで検証。

## 0. ゴール・マイルストーン

### v1.0 (完了)

- M1 移動+カメラで歩ける (P0) ✅
- M2 武器で敵を倒してXPが出る (P1-P2) ✅
- M3 レベルアップ3択ループが回る (P3) ✅
- M4 10分波形+10敵+20カードが揃う (P4) ✅
- M5 ボス2体+勝敗が付く (P5) ✅
- M6 300体でも60fps近く保つ (P6-P7) ✅

### v1.1 (完了)

- **M7 周期的に広がる草原マップを歩ける (P8)** ✅
- **M8 木・岩の裏に隠れる (Yソートが正しい) (P9)** ✅
- **M9 草原と荒野が素材で描画される (P10)** ✅
- **M10 宝箱を開けて9種の中身が出る (P11)** ✅
- **M11 宝箱込みで10分通しプレイが成立し、60fpsを維持 (P12)** ✅

### v1.2 (新規)

- **M12 バランス調整とクリア演出が入る (P13)**
- **M13 宝箱が永続・取得式アイテムになる (P14)**
- **M14 案2込みで10分通しプレイが成立し、回帰が通る (P15)**

### v1.3 (完了)

- **M15 案3 (ノヴァ・タイトル終了・タイトル画像) が入り、回帰が通る (P16)** ✅

### v1.4〜v1.5 (完了)

- **M16 カードマークが選択画面と履歴に出る (P17)** ✅
- **M17 クリアでスタッフロールが主題歌つきで流れる (P18)** ✅

### v1.6 (新規)

- **M18 案4 (カード上限/フォールバック3種・ジェム3段階色・難易度7段階+インセインN・解放セーブ・エンディング後のタイトル導線) が入り、回帰が通る (P19)**

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

### P12 調整・QA [M11] ✅ 完了

- 計測: `tools/playtest_full.gd` (3倍速・逃げ行動・自動カード選択) で4走行。
  宝箱なし4:08死亡 / あり9:02死亡(調整前)・5:28死亡(調整後) / 不死11分走行TIMEOUT (B02生存)。
  いずれもエラー出力なし。不死走行では敵最大297体・60fps維持。
- 適用: cap +12% (`waves_db.gd`)。スケーリング前倒し・回復弱体は見送り (詳細は SPEC §20.4)。
- 修正: 物理フラッシュ中の `add_child` 4箇所を遅延化 (`pool.gd` 成長・`enemy.gd` 分裂・`boss.gd` 報酬・`chest.gd` 開封)。
  いずれも実プレイでエラーが出ていたもの (P12のQAで発見)。
- 静的確認: ボス2体の mask=0 (障害物無視) / 全弾の mask は障害物(64)と無干渉 (遮蔽は見た目のみ) / Yソート境界 y=28 維持。
- **完了条件**: 10分プレイが最後まで破綻なく動き、宝箱込みで「易しすぎない」難易度になっている →
  不死11分走行で破綻なしを確認。自動操作 (人間より弱い) の死亡時刻は4:08〜9:02の範囲。

- 通しプレイ (0→10分、倍速script併用) で宝箱込みのバランスを計測 → §20.1 の順で調整 (cap +10〜15% など)
- パフォーマンス計測: 地面25,600セル + 障害物 + 敵250体 + 弾/ジェムで60fps。チャンク跨ぎのヒッチ確認
- 障害物の詰まり・弾の遮蔽・Yソートの破綻がないか全敵種で確認 (ボス2体は障害物を無視して突進すること)
- SPECとの差分を修正、決定事項チェックリスト (D1〜D16) の承認結果を反映
- **完了条件**: 10分プレイが最後まで破綻なく動き、宝箱込みで「易しすぎない」難易度になっている
- 検証: `run_test_scenario` / `run_stress_test` + 通しプレイのスクショ・ログ

### P13 バランス・スコア・SE・クリア [M12] ✅ 完了

- 実装: スピン複数刃 (COUNT/DMGテーブル) + 敵弾消去 (mask 10・`erase()`) /
  keeper半減速+150px不発 / 8分dmg×1.5 / 撃破スコア (xp×10・ボス別枠) /
  B02分岐修正+3秒カウントダウン / beep 1音色
- 検証: `tools/verify_v12.gd` 16件 ALL PASS (刃数・威力・消去・射撃抑制・減速率・
  スコア・B02→カウントダウン→CLEAR)。回帰 `verify_chests.gd`・`test_gem_magnet.gd` ALL PASS

- `weapons/spin_sword.gd`: 刃をN個化 (`COUNT_TABLE=[1,1,2,2,2,3,3,3]` / `DMG_TABLE=[8〜16]`)、mask 2→10、敵弾の消去
- `projectiles/enemy_shot.gd`: `erase()` 追加 (プール返却+小スパーク)
- `enemies/enemy.gd`: keeper の後退・停止中は shot_cd 半減速、150px以内は発射なし / 撃破時に `add_score(xp_value*10)`
- `systems/spawn_director.gd`: 8分以降 dmg×1.2→×1.5 (1数値)
- `enemies/boss.gd`: B02分岐を修正 (B01:+500/B02:+1000 の撃破スコアも追加)
- `main.gd`: `clear_countdown` (3秒・beep/秒、死亡時はgame over優先)
- `systems/audio_manager.gd`: `beep` 1音色の追加 (カウントダウン用。D27のヘルパーは作らない)
- **完了条件**: スピン3本・敵弾消去・3秒カウントダウン付きクリアが動く。キルでスコアが増える
- 検証: `tools/verify_chests.gd` 回帰 + 新規 `tools/verify_v12.gd` (刃数・消去・射撃抑制・スコア・カウントダウン) + 実機キャプチャ

### P14 宝箱の作り直し [M13] ✅ 完了

- 実装: `objects/chest.gd` HP25+被弾表示、寿命・上限の撤去 / `chest_director` 上限追い出し撤去・
  開封→アイテムスポーン分離 / `objects/item.tscn`+`item.gd` 新規 (接触26・マグネット無効・永続) /
  素材 heart/star/magnet/sword + coin/bomb/ジェム流用
- 検証: `verify_chests.gd` を新仕様に更新 ALL PASS + `verify_v12.gd` に5件追加
  (開封ドロップ・取得適用・T03設置・引き寄せなし) ALL PASS (計21件)

- `objects/chest.gd`: HP25 + 被弾表示 (damage_number+白フラッシュ)、寿命・上限の撤去
- `systems/chest_director.gd`: 上限追い出し・`expire_silent` の撤去、開封はアイテムスポーンに分離
- `objects/item.tscn` + `item.gd` 新規 (接触26・マグネット無効・永続・上下動・Yソート、取得で `apply_item`)
- 素材: 1min-image で heart/star/magnet/sword の1シート (2x2) → 48x48 整列。coin/bomb/ジェム流用
- **完了条件**: 宝箱が残り続け、開けるとアイテムが飛び出し、拾うと効果が出る
- 検証: `verify_v12.gd` に追加 (永続・HP25・取得適用・T03取得設置) + 実機キャプチャ

### P15 QA・仕上げ [M14] ✅ 完了

- 通しプレイ (`playtest_full.gd` 3倍速・自動操作):
  - 通常: t=341 死亡 (Lv5・148kill・19宝箱・score 2160)、別走で t=518 死亡
    (Lv4・213kill・23宝箱)。v1.1 (宝箱なし4:08/あり5:28) 比で生存が伸び、
    10分ゲームとして自動操作でも5〜9分もつ難易度。数値調整なし。
  - 不死: 11分 TIMEOUT (Lv11・460kill・35宝箱・score 7080、fps60維持)。
    ボス撃破は自動操作の限界 (P12と同様、TIMEOUT enemy_boss_alive)。
  - 両走行とも SCRIPT ERROR 0。min_fps=1 は起動直後の初回サンプルのみ (以降60)。
- 全回帰 ALL PASS: `verify_world`・`verify_obstacles`・`verify_chests`・`verify_v12` (24件)・
  `verify_feedback_look` (6件)・`test_gem_magnet` + スモークキャプチャ (エラー0)。
  SE は単音機構のまま (D27対象外のため耳確認は beep のみ)。
- SPEC §23 との差分を修正: §23.1 放射状・§23.6 T09ポップアップ を追記、§23.0 D27行に注記。

- 通しプレイ (`playtest_full.gd`、通常+不死) でD17〜D27の複合バランスを確認 → 必要なら数値微調整
- 全回帰 (`verify_*.gd`、`test_gem_magnet.gd`) + 実機キャプチャ + SE耳確認
- SPEC §23 との差分を修正
- **完了条件**: 10分プレイが破綻なく動き、verify 全PASS。v1.2 完了

### P16 バージョンアップ案3 [M15] ✅ 完了

- 実装: `items_db` T10重み4 / `chest_director` T10分岐 (700px内80dmg+敵弾全消去+警告) /
  `item` nova絵対応 / `item_nova.png` 生成・48x48整列 /
  タイトル終了ボタン→`quit_pressed`→`quit()` / `title_art.png` 生成・最背面配置・Dim 0.55
- 検証: `verify_v13.gd` 新規15件 ALL PASS (重み・抽選・効果・弾消去・取得発動・終了接続・絵)。
  回帰 `verify_chests`・`verify_v12` (取得テストの敵掃除で安定化)・`verify_audio` ALL PASS

- `data/items_db.gd`: T10「ノヴァ」重み4を追加 (合計100→104)
- `systems/chest_director.gd`: `apply_item` に T10 分岐 (画面内700pxに80dmg + 敵弾全消去 + 大poof/explode/警告)
- `objects/item.gd`: `nova` の絵と ID 対応を追加 (取得式・接触26・無引き寄せは共通)
- `objects/sprites/item_nova.png`: 1min-image 生成 → 48x48 整列
- `ui/title_ui.tscn` + `title_ui.gd` + `main.gd`: 終了ボタン → `quit_pressed` → `get_tree().quit()`
- `ui/title_art.png`: ピクセルアート生成 → TitleUI 最背面に配置、Dim 0.94→0.55
- **完了条件**: ノヴァ取得で画面一掃が起き、タイトルから終了でき、タイトルに絵が出る
- 検証: 新規 `tools/verify_v13.gd` (T10抽選・効果・弾消去・終了接続・絵の存在) + 全回帰

### P17 カードマーク表示 [M16] ✅ 完了

- 実装: `data/card_marks.gd` 新規 (21種の24pxドット絵を実行時生成) /
  `card_manager` が提示に `icon` を付与 /
  `levelup_ui` を絵+ラベル構成に変更 (約112px表示、ボタン320x340) /
  `main` HUD下部に取得順の24px履歴列 (下端基準の複数行レイアウト) /
  デバッグ文 (`InfoLabel`) は右下・履歴の上へ移動 /
  T09/R_WEAPON の武器強化も強化先の武器マークとして履歴に記録
- 検証: 新規 `tools/verify_card_marks.gd` (生成・大表示・取得順・アイテム強化・複数行・枠内収まり・右下集約) +
  `tools/capture_card_marks.gd` で実機撮影し画素で描画確認
- **完了条件**: 選択画面の3枚に大きめのマークが出て、取得した順に下部へ小マークが複数行で並ぶ
- デバッグ文は右下・履歴の上へ移動。T09/R_WEAPON の武器強化も履歴に記録する

### P18 スタッフロール [M17] ✅ 完了

- 実装: `ui/staff_roll_ui.tscn` + `staff_roll_ui.gd` 新規 /
  リザルトの「スタッフロールへ」ボタンで進行 (戦績は `start_roll(stats)` でヘッダーに) /
  開始は CLEAR!/戦績残しフェード+曲尺いっぱいスクロール (段落間5行空き)・音楽2秒遅延・スキップ即最終画面 /
  `main` に StaffRollUI 配線 (開始・リトライ/タイトル再読込・ポーズガード) /
  主題歌 `audio/music/vansaba_theme_1.mp3` (実測約251秒) をコミット
- 検証: 新規 `tools/verify_staff_roll.gd` 48件 (出し分け・フェード・実ノード剛体・交換・曲尺同期・音楽遅延・歌詞バー・スキップ・自然終了・配線) +
  全回帰 ALL PASS。`verify_v13` のT10取得待ちを状態ベースに修正
- **完了条件**: クリア→リザルト→スタッフロールで主題歌が流れ、曲終わりと同時に Thanks が中央に残る
- 回帰は `--fixed-fps 60` 決め打ち (§5)。高速headlessで固定フレーム待ちが足りず誤失敗するため

### P19 バージョンアップ案4 [M18]

- 実装: `data/difficulty_db.gd` 新規 (7段階+インセインNの表・乗数ヘルパ・`static current`) /
  `systems/save_data.gd` 新規 (`user://vansaba_save.json` の読み書き) /
  `systems/card_manager.gd` (Lv表記の1段ずれ修正・MAX除外の保証・フォールバック3種の抽選) /
  `data/card_marks.gd` (kind `xp`/`nova` の台座 + 修練の書/ノヴァのマーク2種) /
  `pickups/xp_gem.gd` + `xp_gem.tscn` (3段階色 + 金のきらめき) /
  `enemies/enemy.gd`・`enemies/boss.gd`・`projectiles/enemy_shot.gd`・`systems/spawn_director.gd` (難易度の適用 §31.5) /
  `ui/title_ui.tscn`+`title_ui.gd` (難易度セレクタ・◀▶ボタン・鍵・右側パラメータ表) /
  `main.gd` (難易度の受け渡し・クリア時の解放保存・`--difficulty`/`--unlock-all`) /
  `ui/result_ui.gd`・HUD (難易度名・解放通知) /
  `ui/staff_roll_ui.tscn`+`staff_roll_ui.gd` (エンディング後のボタンを「タイトルへ」のみに・`retry_pressed` と配線の削除・`EndHint` 文言) +
  `main.gd` の staff retry 配線削除
- 検証: 新規 `tools/verify_v16.gd` (難易度の乗数・解放ルール・セーブ往復と破損時フォールバック・
  フォールバック3種の重複なし・MAX除外1000回・ジェム3色と位相・Lv表記) + 全回帰
  (うち `verify_staff_roll.gd` は「リトライボタン不在・タイトルボタンのみ・staff retry 配線なし」に更新)
  + `playtest_full.gd --difficulty hard` の通し計測 + インセインでの fps 実測 (同時上限クランプの確定)
- **完了条件**: タイトルで難易度を選んで開始でき、クリアで解放が保存される。MAXカードは候補に出ず、
  プール枯渇時は3種が並ぶ。ジェムが緑/赤/白で光る
- SPEC §31.4 の数値は初版。計測結果で確定して SPEC に書き戻す (P12と同じ流儀)

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
| (v1.6) 高難易度で敵が増えすぎ fps 低下 | 出現量は同時上限 ×(1+S/200) + 400体クランプ。P19 で実測し、係数とクランプを確定して SPEC に書き戻す |
| (v1.6) セーブが壊れてタイトルが動かない | 読み込み失敗時は初期状態 (ノーマルのみ) に戻す。検証で破損ファイルの往復を assert |
| (v1.6) 難易度の掛け忘れ/二重掛け | 適用点を §31.5 の3箇所に限定し、ノーマル = 完全 no-op を回帰で保証 (verify_v16) |
| scope肥大 | v1.6対象外 (メタ成長・実績・リロール等) は入れない |

## 5. 検証コマンド

- 構築: `create_scene`, `batch_add_nodes`, `create_script`, `attach_script`, `save_scene`
- 実行: `play_scene` → `simulate_key/mouse_click/action` → `get_game_screenshot/capture_frames/monitor_properties/assert_node_state` → `stop_scene`
- 調査: `get_scene_tree`, `read_script`, `get_editor_errors`, `get_output_log`
- ヘッドレス (MCP経由が不安定なとき): `godot --headless --fixed-fps 60 --path <proj> --script res://tools/verify_*.gd`
  (`--fixed-fps 60` 必須。固定フレーム待ちのテストが高速headlessでは短時間化して誤失敗するため。v1.5で判明)
- 注意: ヘッドレス起動で `project.godot` の `[autoload]` が落ちることがある → コミット前に `git checkout -- project.godot`

## 6. 次アクション提案

1. SPEC.md §32 の決定事項チェックリスト (D33〜D42) を確認・承認する
2. 承認後 P19 を実装 (難易度DB → 適用 → タイトルUI → カード/ジェム → セーブ → 計測)
3. 実装ブロッカーは D36 (難易度の数値とパラメータ表)・D39 (セーブ形式)・D40 (セレクタUI) — ここが決まれば
   D33〜D35 (カード・ジェム) は独立して進められる
