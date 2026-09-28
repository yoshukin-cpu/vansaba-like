# 実装計画 v1.9

> 前提: SPEC.md v1.9 / Godot 4.7.2 / v1.0〜v1.7 実装済み (P0〜P20 完了。P20 は窓ありキャプチャの目視のみ残り)。
> v1.1 以降は `IDEA.md` の「バージョンアップ案1〜6」を順に実装する計画として積み上げている。v1.7 = 案5、v1.8 = 案6 (実装完了・検証中)。v1.9 = ライセンス表示・公開前準備 (設計: 承認待ち。SPEC §37・D84〜D92)。
> 方針: データ駆動・仮素材・小さく動くものを反復。Editor toolsで構築、Runtime toolsで検証。
> 公開前の準備 (ライセンス同梱・クレジット表示) は §7 (2026-09-28 監査)。未消化項目は v1.9 設計 (SPEC §37) で確定し、P26 で実装する。

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

### v1.6 (完了)

- **M18 案4 (カード上限/フォールバック3種・ジェム3段階色・難易度7段階+インセインN・解放セーブ・エンディング後のタイトル導線・エンディング背景の上端合わせ) が入り、回帰が通る (P19)** ✅

### v1.7 (実装中)

- **M19 案5 (D44〜D57) が入り、回帰が通る (P20)**

### v1.8 (実装完了・検証中)

- **M20 案6 (BGM 3曲と切替・オプション・コイン/恒久強化・射程・エリート/最終ボス×2) が入り、回帰が通る (P21〜P22)**

### v1.9 (実装完了)

- **M21 全公開物 (リポジトリ/exe/Web) にライセンス文・帰属が同梱され、ゲーム内から参照できる (P26)** ✅

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

### P19 バージョンアップ案4 [M18] ✅ 完了

- 実装: `data/difficulty_db.gd` 新規 (7段階+インセインNの表・乗数ヘルパ・`static current`) /
  `systems/save_data.gd` 新規 (`user://vansaba_save.json` の読み書き) /
  `systems/card_manager.gd` (Lv表記の1段ずれ修正・MAX除外の保証・フォールバック3種の抽選) /
  `data/card_marks.gd` (kind `xp`/`nova` の台座 + 修練の書/ノヴァのマーク2種) /
  `pickups/xp_gem.gd` + `xp_gem.tscn` (3段階色 + 金のきらめき) /
  `enemies/enemy.gd`・`enemies/boss.gd`・`projectiles/enemy_shot.gd`・`systems/spawn_director.gd` (難易度の適用 §31.5) /
  `ui/title_ui.tscn`+`title_ui.gd` (難易度セレクタ・◀▶ボタン・鍵・右側パラメータ表) /
  `main.gd` (難易度の受け渡し・クリア時の解放保存・`--difficulty`/`--unlock-all`) /
  `ui/result_ui.gd`・HUD (難易度名・解放通知) /
  `ui/staff_roll_ui.tscn`+`staff_roll_ui.gd` (エンディング後のボタンを「タイトルへ」のみに・`retry_pressed` と配線の削除・`EndHint` 文言・背景 `_layout_art()` の上端合わせ) +
  `main.gd` の staff retry 配線削除
- 検証: 新規 `tools/verify_v16.gd` (難易度の乗数・解放ルール・セーブ往復と破損時フォールバック・
  フォールバック3種の重複なし・MAX除外1000回・ジェム3色と位相・Lv表記) + 全回帰
  (うち `verify_staff_roll.gd` は「リトライボタン不在・タイトルボタンのみ・staff retry 配線なし・背景の上端合わせ (上端0/横中央/画面を覆う)」に更新)
  + `playtest_full.gd --difficulty hard` の通し計測 + インセインでの fps 実測 (同時上限クランプの確定)
- **完了条件**: タイトルで難易度を選んで開始でき、クリアで解放が保存される。MAXカードは候補に出ず、
  プール枯渇時は3種が並ぶ。ジェムが緑/赤/白で光る
- SPEC §31.4 の数値は初版。計測結果で確定して SPEC に書き戻す (P12と同じ流儀)
- 実測: 通しプレイ (3倍速) ノーマル 8:42 (Lv10/597kill) / ハード 8:36 (Lv6/191kill・撃破 -68%)。
  インセイン+不死11分: 敵最大427体・fps99〜127 (headless) → 上限クランプ400を確定。数値は初版のまま。
  `verify_v16.gd` 107件 ALL PASS + 全回帰 ALL PASS。実機キャプチャ (`capture_title_diff`・`capture_finale`) で
  解放/未解放の2状態とエンディング (月が見える・ボタンはタイトルへのみ) を目視確認

### P20 バージョンアップ案5 [M19] (検証中: headless 完了・窓あり目視が残り)

- 実装: `ui/staff_roll_ui.gd` (D44 解放通知を残す) + `ui/result_ui.gd` (`hide_unlock_notice` 削除) /
  `ui/title_ui.gd` (D45 DiffLock 固定・D46 スティックラッチ) /
  `weapons/orbit_bomb.gd` (D47 最低距離160・D48 `_pick_target`/`_find_unused`) /
  `enemies/enemy.gd` (D49 `_apply_variance`) / `pickups/xp_gem.gd` (D50 閾値1/4/8) + `enemies/wolf.tscn` (XP4) /
  `projectiles/projectile.gd` (D51 初回走査・D54 `visual_scale`) / `systems/card_manager.gd` (D52 MAX表示) /
  `weapons/spin_sword.gd` (D53 拡大+残像) / `weapons/straight_shot.gd`・`weapons/homing_missiles.gd`・`weapons/flamethrower.gd` (D54) /
  `projectiles/homing_projectile.gd` (D55 煙) / `weapons/chain_lightning.gd` + `systems/combat_fx.gd` (D56 burst・上限128) /
  `objects/bomb.gd` (D57 48破片・速遅分離・敵配列キャッシュ)
  - 追補 (チャット要望): `projectiles/homing_projectile.gd` (D58 煙の視認性・後方±5°ぶれ) /
    `weapons/lightning_fx.gd` + `weapons/chain_lightning.gd` (D59 線の太さLv連動・D60 飛び散る火花) +
    `systems/combat_fx.gd` (D60 `streak` 追加) /
    `ui/title_ui.gd` (起動時セーブ読み込み順の修正・パッド「終了」不具合修正) /
    `weapons/spin_sword.gd` (残像ノードの残留修正)
- 検証: 新規 `tools/verify_v17.gd` (ばらつき範囲・ボム投下点・密着ヒット・見た目係数・煙・破片48・線の太さ) +
  `verify_v16.gd` 更新 (範囲 assert・閾値4/8・MAX表記・DiffLock 空行・解放通知残存) +
  `verify_staff_roll.gd` 更新 (解放通知残存) + `tools/verify_title_load.gd`・`tools/test_title_input.gd` (タイトル系の回帰) +
  通しプレイ + 全回帰
- **完了条件**: 案5の11項目がすべて動き、verify 全PASS。見た目変更は判定・数値に影響しない
- 実測: `verify_v17.gd` 50件 ALL PASS (D58〜D60 追補・スピン残像の残留修正込み) + `test_title_input.gd` 50件 ALL PASS (ロック中+パッド終了の回帰込み) +
  `verify_title_load.gd` 9件 ALL PASS + 全回帰 (headless) ALL PASS。
  通しプレイ (3倍速・通常) 9:43 死亡 (Lv9・312kill・score 5620) エラーなし。残りは窓ありキャプチャ (見た目系) の目視。

### P21 BGM・音量・オプション [M20-1] (実装完了: verify 35+48件 ALL PASS・窓あり目視済み)

- 素材: 1min-image (Suno・`instrumental: true`) で BGM 3曲を生成し、`audio/music/bgm_title.mp3`・`bgm_game.mp3`・`bgm_boss.mp3` に格納
  (プロンプト方針は SPEC §35.1 の表。1曲=1生成・2曲目は使わない)。`--headless --import` で取込
- 実装: `audio/default_bus_layout.tres` 新規 (Master/BGM/SE) + `project.godot` (bus 設定・viewport 1152×648 の明文化・`window/stretch/aspect="keep"`) /
  `systems/bgm_manager.gd` 新規 (3 player・process_mode ALWAYS・状態 title/game/boss/silent・フェードと `_game_pos` 再開) +
  `main.tscn` に `BGM` ノード + `main.gd` の状態配線 (start_game/死亡/クリア/リトライ/スタッフロール) /
  `systems/audio_manager.gd` を SE バスへ /
  `ui/options_ui.tscn` + `options_ui.gd` 新規 (表示モード・解像度16件 (4Kまで)・BGM/SE音量・スタッフロール再演 (解放までは非表示)・戻る) /
  `ui/title_ui.tscn` + `title_ui.gd` に「オプション」ボタン /
  `ui/staff_roll_ui.gd` に再演モード (`start_roll(null)`・HeaderRoll 文言・保存を呼ばない)
- 検証: `tools/verify_bgm.gd` 新規 (状態遷移・フェードの音量・`_game_pos` 再開・paused 中も鳴る) /
  `tools/verify_options.gd` 新規 (既定値・保存往復・v1 セーブ互換・bus 音量・モード/解像度の値・**未解放では再演の行が存在しない (秘密項目)**) /
  `tools/capture_options.gd` (窓ありで解像度16件と黒帯を撮影し目視 + **4K (3840×2160) の fps を実測**) + BGM の耳確認 (ボス切替・ループ継ぎ目・ゲーム中の抑え具合) /
  `verify_staff_roll.gd` に再演モードを追加
- **完了条件**: タイトル・ゲーム中・ボスで BGM が鳴り、ボスで切替わって倒すと続きから戻る。オプションでウィンドウ/フルスクリーン・解像度・音量・スタッフロール再演が使える
- 実測 (P21 完了): `tools/verify_bgm.gd` 35件・`tools/verify_options.gd` 48件 ALL PASS + 全回帰 (headless) ALL PASS。
  窓あり `tools/capture_options.gd` で6枚キャプチャ (タイトル/オプション/強化/4:3/16:10/4K) し、目視で確認。
  4K は 3754×2112 にクランプして開き (使用領域 3840×2112)、min 59 / avg 59.7 fps (vsync 60)。フルスクリーン (3840×2160) は 59.8 fps。
  検証中に判明した不具合を修正: (1) BGM マネージャ自身が paused で止まりフェードが凍る → `process_mode = ALWAYS`、
  (2) タイトル「終了」がデフォルト解像度で見切れる (チャット要望 D73) → 左下固定 + 上下ナビ明示配線。

### P22 コイン・恒久強化・バランス [M20-2] (実装完了: verify_v18 60件 ALL PASS。通し計測が残り)

- 実装: `data/meta_upgrades.gd` 新規 (8項目・コスト式 `基準+増分×Lv`・ラン開始時の適用) /
  `data/difficulty_db.gd` (`ELITE_SCALE`/`MID_BOSS_SCALE`/`FINAL_BOSS_SCALE`・`COIN_MULT`/`coin_mult`) /
  `systems/save_data.gd` v2 (coins/upgrades/options・v1 互換・`add_coins`) /
  `systems/chest_director.gd` (T02 +1 / R_COIN +10 のコイン加算) /
  `main.gd` (`run_coins`・HUD コイン・リザルト確定・メタ適用・`--coins`) + `main.tscn` に HUD `CoinLabel` /
  `ui/upgrade_ui.tscn` + `upgrade_ui.gd` 新規 + `ui/title_ui.*` (「強化」ボタン・`CoinLabel`・`confirm_focused` 拡張) /
  `ui/result_ui.gd` (コイン確定行) /
  `weapons/weapon_base.gd` (`aim_range`) + `weapons/straight_shot.gd`・`homing_missiles.gd` (寿命 1.0s/1.5s・aim_range 上書き) +
  `projectiles/homing_projectile.gd` (再探索を残り寿命×速度に) /
  `ui/staff_roll_ui.gd` (BGM/コイン・強化のページ追加)
- 検証: `tools/verify_v18.gd` 新規 (コスト式・購入・メタ適用の no-op/乗算・コイン入手と確定・倍率表・実効射程・aim_range・エリート/ボス倍率) /
  `verify_v16.gd` 更新 (エリート比 2.4・エリートHP ×2・B02 ×2 assert 追加。**B01 の 2250 は据え置き**) /
  `verify_chests.gd`・`verify_v12.gd` 更新 (コイン +1/+10) / `verify_staff_roll.gd` 更新 (ページ増) /
  全回帰 / `playtest_full.gd` 通し (コイン回収量・ボスTTK・撃破数を v1.7 と比較) / 窓あり目視 (強化画面・リザルトのコイン行)
- **完了条件**: コインが貯まり、強化で少し強くなって開始できる。射程とエリート/最終ボス×2 (中ボス据え置き) が計測で確認され、回帰が全PASS
- 数値 (コスト・難易度倍率・`ELITE_SCALE`/`FINAL_BOSS_SCALE`・射程) は初版。P22 の計測で確定して SPEC に書き戻す (P12/P19 と同じ流儀)
- 実測 (P22 実装分): `tools/verify_v18.gd` 60件 ALL PASS (係数・エリート/ボスHP の実測・コイン入手/確定・メタ適用の no-op と乗算・射程・追尾の再探索)。
  回帰更新は `verify_v16` (エリート比 2.4/HP ×2・B02 15000)・`verify_chests`・`verify_v12` (コイン+1/+10)・`verify_staff_roll` (再演モード)・
  `verify_v13`/`test_title_input` (D73)。残りは通し計測 (コイン回収量・ボスTTK・撃破数) と BGM の耳確認。

### P23 オプションの操作改善・セーブ初期化・再演フロー [M20-3] (v1.8 追補2・D74〜D78)

- 実装: `ui/options_ui.*` (◀▶ ボタン・行クリック・フォーカス解放・初期化+確認・ヒント) /
  `ui/upgrade_ui.*` (フォーカス解放・購入ボタン・戻るクリック) / `systems/save_data.gd` (`reset_progress()`) /
  `ui/replay_countdown_ui.*` 新規 (3→2→1) / `ui/result_ui.*` (再演デモ + 「スタッフロールを見る」) /
  `ui/staff_roll_ui.gd` (`start_roll(res, replay)`) / `ui/title_ui.gd` (`focus_start()`) / `main.gd` (再演フローの組み立てと入力ガード)
- 検証: `tools/verify_options.gd` 拡張 (入力隔離・◀▶ のクリック・キーボード操作・初期化と確認・オプション保持) +
  `tools/verify_replay_flow.gd` 新規 (カウントダウン→リザルト→ボタン→ロール・保存なし) + 全回帰
- **完了条件**: オプション/強化を開いている間タイトルが動かない。マウスだけで全項目を操作できる。初期化で進行状況だけが消えて
  オプション設定は残る。再演がカウントダウン→リザルト→ボタン→フェード→ロールで進む。
- 実測 (P23 完了): `verify_options.gd` (§7/§8 追加)・`verify_replay_flow.gd` (新規)・`verify_options_mouse.gd` (窓あり実クリック) ALL PASS + 全回帰 ALL PASS。
  途中で見つけた不具合を修正: 「戻る」実行ボタンの文言が空 (`match` を action ではなく id="back" で引いていなかった)。
  環境の注意: headless はマウス入力が GUI に届かず、ルート viewport も 100×100 のため、クリック系は窓ありで検証する
  (stretch keep の座標変換 = キャンバス座標×等比+中央寄せが必要)。

### P24 アプリ名・BGM音量・難易度ロック表示・スティックラッチ・タイトルのメニュー配置 [M20-4] (v1.8 追補3・D79〜D83)

- 実装: `project.godot` (`application/config/name = "Vansaba Like!"`) / `systems/save_data.gd` (`_migrate_legacy_save()` =
  旧名セーブの一度きりの引継ぎ。`legacy_path` は検証から差し替え可) / `systems/bgm_manager.gd` (`TRACK_DB["game"] = -10.0`) /
  `ui/title_ui.tscn` (左側の `LeftMenu` に 強化/オプション/終了 を縦並び・中央の `MenuRow` を削除) /
  `ui/title_ui.gd` (フォーカス配線・ロック中の「ノーマル」を暗く + ◀▶ 無効) / `ui/options_ui.gd` (左右のスティックラッチ `_axis_armed_h`)
- 検証: `tools/verify_v13.gd` (アプリ名・左カラムの縦並びと座標・難易度ロック中の暗色と ◀▶ 無効)・
  `tools/test_title_input.gd` (左カラム経由の ↓ 移動で 終了)・`tools/verify_options.gd` (スティック倒しっぱなしで1回だけ変化)・
  `tools/verify_bgm.gd` (game −10dB)・`tools/verify_options.gd` に旧セーブ引継ぎ・全回帰
- **完了条件**: ウィンドウタイトルが「Vansaba Like!」。既存セーブが引き継がれる。ゲーム中の BGM が聞き取りやすい。
  初期状態 (未クリア) で「ノーマル」が暗い。オプションの◀▶がスティック倒しっぱなしで連続しない。タイトルのメニューが左に縦並びで ↑↓ のみで移動。
- 修正 (チャット要望): ロック中の難易度 (はじめる無効) のまま強化画面を開いて B/戻るで閉じると、`focus_start()` が
  disabled のため何もせずフォーカスが空になり、囲みが消えて ↑↓ でも選べなくなる (パッド不具合)。
  「開く直前にフォーカスしていた有効なボタン (無ければ左メニュー先頭)」へ戻す + フォーカスが空でも ↑↓ で復帰する保険を追加。
  検証: `test_title_input.gd` ケース11 (強化)・12 (オプション) 追加で 65件 ALL PASS。修正前コードでは2件 FAIL を確認。

### P26 ライセンス・クレジット整備 [M21] (v1.9・D84〜D92) (実装完了: verify_license 33件 + 回帰 19本 ALL PASS・窓あり7枚確認)

- 文書 (設計 §37.2/§37.3 の確定案をそのまま実体化): `LICENSE` (MIT・© 2026 yoshuki)・`THIRD_PARTY_NOTICES.md` (6節)・`README.md` にライセンス節
- コミット (ユーザー格納済みの未コミット分): `GODOT_COPYRIGHT.txt`・`addons/godot_mcp/LICENSE`・`font/` (本体2 + LICENSE.txt + OFL.txt + .import 2)
- ゲーム内: `ui/license_ui.*` 新規 (全画面スクロール・テキスト定数内蔵) + `ui/options_ui.gd` に行「ライセンス・商標表示」 (`license_pressed`) + `main.gd`/`main.tscn` の導線 (オプション ⇔ ライセンス画面・閉じたらオプションへ戻す)
- クレジット: `ui/staff_roll_ui.gd` は**ユーザー先行実装済み** (「1min.ai」「GPT Image 2」・2026-09-28)。`verify_staff_roll.gd` は追随済み (ALL PASS)。残りはドキュメントの素材メモ更新
- ロゴ: `icon.svg` 差し替え (`tools/make_icon.py` で生成) + `ui/boot_splash.png` 新設 + `project.godot` (`application/boot_splash/*`)
- 配布: `tools/make_release.py` (zip 組み立て)・`export_presets.cfg` の Windows メタデータ記入・Web フォルダへのライセンス同梱
- 未コミット設定の扱い: `project.godot` の `[gui]` フォント行・`window/stretch/aspect="expand"` (ユーザー設定) をそのままコミット (SPEC §35.3 に v1.9 注記)
- 検証: `verify_license.gd` (新規)・`verify_options.gd` (行構成/`license_pressed`)・`verify_staff_roll.gd` (追随済み)・窓あり `capture_license.gd` とブートスプラッシュ目視・`--headless --import`・**全回帰 ALL PASS**。実測件数を SPEC 更新履歴/README に書き戻す
- **完了条件**: §7.4 のとおり (全公開物にライセンス文・ゲーム内から参照できる・ロゴ差し替え済み・§7.3-D の確認事項 3 件の解消)
- 実測 (P26 完了): `verify_license.gd` 33件 ALL PASS。回帰 19 本 (`verify_options`/`verify_staff_roll`/`verify_replay_flow`/`test_title_input`/`verify_v12/v13/v16/v17/v18`/`verify_bgm`/`verify_audio`/`verify_card_marks`/`verify_chests`/`verify_seed`/`verify_title_load`/`test_gem_magnet`/`test_projectile_hit`/`verify_world`) ALL PASS + 旧観測スクリプト 9 本 例外0。
  exe 実測 (PowerShell VersionInfo): ProductName「Vansaba Like!」・CompanyName「yoshuki」・LegalCopyright「(c) 2026 yoshuki — MIT License. Third-party notices: THIRD_PARTY_NOTICES.md」。
  Web 実測: favicon 256×256・apple-touch-icon 180×180 = 新アイコン、`vansaba-like.png` 1024×576 = 新スプラッシュ (既定の Godot ロゴ 800×600 が消滅)。
  リリース: `export/release/VansabaLike_v1.9_win64.zip` (122.2MB) = exe + LICENSE + THIRD_PARTY_NOTICES.md + licenses/ (GODOT_COPYRIGHT・font×2・godot_mcp)。Web フォルダにも同梱済み。
  窓あり: `capture_license.gd` 7 枚でライセンス画面 (MIT/OFL 全文・リンク・商標) を目視。残りはユーザーの最終目視と公開判断。
- 修正 (2026-09-28・ユーザー報告): ライセンス画面が操作不能 (キー/パッド/マウス・戻るボタンも無反応)。
  原因 = `ui/license_ui.tscn` の `process_mode = 3` 未設定 (タイトルは paused = true のため描画のみで入力が届かない。既存モーダルは全て tscn で設定済みの規約)。
  `process_mode = 3` 追加 + A/Enter でも閉じる追補。`verify_license.gd` に実入力経路 7 件を追加 (修正前 FAIL 4 件の再現 → 修正後 40件 ALL PASS)。
  窓あり `capture_license.gd` 8 枚 (実マウスクリックで戻るボタン → オプション復帰)。exe/Web 再書き出し・リリース zip 再生成 (124.1MB) 済み。
- 追補 (チャット要望 D94): ライセンス画面 — ↑↓/スティックは **0.5s 押しっぱなしで連続スクロール** (REPEAT_STEP 0.06s・`Input.is_action_pressed` ポーリング = キー/スティック共通)、**←→ = 1 ページ送り** (ビューポート − 1 段・スティック左右はラッチ)。
  `verify_license.gd` に 10 件追加し **50件 ALL PASS**。窓ありでヒント行の収まりを確認。exe/Web/zip 再生成 (18:51)。

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
| (v1.8) BGM のループ継ぎ目・音量が合わない | mp3 の `loop` を有効化。継ぎ目が耳につく場合のみ ffmpeg で OGG へ変換。トラック基準音量 (−8/−14/−10dB) は P21 で耳確認して調整 |
| (v1.8) 解像度変更で UI が崩れる | 内部解像度 1152×648 固定 + `keep` (黒帯) で伸縮は等比のみ。窓あり `capture_options` で16解像度 (4K 含む) を目視 (アンカー崩れの確認) |
| (v1.8) セーブ v2 でタイトルが壊れる | v1 互換の読み込み + 破損時は初期化。verify_options で往復と v1 ファイルの読込を assert |
| (v1.8) コイン経済が渋い/甘い | コストと難易度倍率は初版。P22 の通し計測で回収量を実測し、全MAX 2,205 コインを基準に調整して SPEC に書き戻す |
| (v1.8) エリート/最終ボス ×2 が高難易度で過剰 | エリート ×2・最終ボス ×2・中ボス据え置き (全難易度)。P22 で両ボスの TTK を計測し、過剰なら `ELITE_SCALE`/`FINAL_BOSS_SCALE` を下げる |
| (v1.8) 射程短縮でストレートが弱くなりすぎる | 実効射程 = C02 500px・C03 630px (曲がるため長め) + エイム射程の一致で無駄撃ちを除去。通し計測で撃破数を v1.7 と比較し、必要なら C02 を 576〜640px へ緩める |
| scope肥大 | v1.8 対象外 (ポーズからのオプション・C05 の射程・実績等) は入れない |
| (v1.8) Web 書き出しで BGM/歌詞が欠ける | Web プリセットの `include_filter` に `*.txt` (非リソースの歌詞)。BGM の再開位置は `get_playback_position()` を使わず自前計測 + 曲長で折り返す (P25) |

### P25 Web 書き出しの不具合修正 (2026-09-28・ユーザー報告)

- 症状 (Web 書き出しのみ・exe は正常): ①中ボス撃破後にゲーム中の BGM が鳴らない ②スタッフロールの歌詞が出ない
- 原因①: Web の `AudioStreamPlayer.get_playback_position()` は**ループしても 0 に戻らず累積**し、実時間とも大きくずれる
  (位置報告 Worklet に巻き戻しがなく、Worklet が毎クオンタム処理されない)。5分走ると 94.8s の曲で ~300 を返すため
  `play(300.0)` が呼ばれ、**WebAudio では曲長以上の offset = 無音** + 「無音→ended→再start」の空ループになる
  (ブラウザ実測: 2s クリップに `play(4.0)` → 出力 0・`start` が秒間数百回。範囲内なら鳴る)。
  exe は Godot が曲長で折り返した正しい位置を返すため気づかなかった。
- 修正①: `systems/bgm_manager.gd` — 経過時間を自前計測 (`game_elapsed`。`process_mode = ALWAYS` の `_process` で加算) し、
  保存時に `fposmod(経過, 曲長)` で `0 <= 位置 < 曲長` に畳む。ボス撃破後は従来どおり「フェードアウトした続き」から再開。
  曲長が読めないときは頭 (= 0) から鳴らす (無音回避を優先)。→ SPEC §35.1 に追記
- 原因②: 歌詞 `audio/music/vansaba_theme_lyrics_timing.txt` は非リソース (`.import` なし) で、**Web プリセットの
  `include_filter` が空**だったため pck に入っていなかった (Windows プリセットは `*.txt` があり正常)。`FileAccess.open` が
  null を返し、歌詞は無言で空配列 → バーが出ないだけだった。
- 修正②: `export_presets.cfg` の Web プリセットに `include_filter="*.txt"`。
  ※ pck 内に入るため**配布物のライセンス同梱には使えない** (§7.3-C の注意どおり)。
- 検証: `tools/verify_bgm.gd` に「曲長を超えた経過時間でも保存・再開位置が曲長未満に畳まれる」を追加
  (3周 + 12.5s を強制 → 12.517 に畳まれる) — ALL PASS (既存分含む)。
  Web は実ブラウザで実測: ボス撃破で `start(offset=12.005, len=94.813)` = 範囲内・続き位置から再開し、出力 RMS > 0。
  歌詞は pck 同梱 (grep) + 書き出し内の `theme_lyrics.load_timed()` が 41 行返すことを確認。
  - 計測の注意: 自動再生ポリシーのため**ユーザー操作 (クリック) で AudioContext を resume** させる。ページは前面に
    出しておく (`Page.bringToFront`。裏だと rAF が止まりゲームが進まない)。AudioContext を同時に多数開くと
    新しいタブが無音になることがあるため、計測は少ないタブで行う。

## 5. 検証コマンド

- 構築: `create_scene`, `batch_add_nodes`, `create_script`, `attach_script`, `save_scene`
- 実行: `play_scene` → `simulate_key/mouse_click/action` → `get_game_screenshot/capture_frames/monitor_properties/assert_node_state` → `stop_scene`
- 調査: `get_scene_tree`, `read_script`, `get_editor_errors`, `get_output_log`
- ヘッドレス (MCP経由が不安定なとき): `godot --headless --fixed-fps 60 --path <proj> --script res://tools/verify_*.gd`
  (`--fixed-fps 60` 必須。固定フレーム待ちのテストが高速headlessでは短時間化して誤失敗するため。v1.5で判明)
- 注意: ヘッドレス起動やエディタ保存で `project.godot` の `[autoload]` 行 (MCP 用3つ)・`export_presets.cfg` の `include_filter` が落ちることがある →
  **復元してからコミットする**。「コミット前に `git checkout -- project.godot`」は**使わない** (ユーザーの未コミット設定 [フォント・stretch] まで消える。2026-09-28 に実例)

## 6. 次アクション提案

1. **v1.9 (ライセンス表示・公開前準備)**: SPEC §37 の承認 (推奨案で一括) → **P26 を実装** (文書 → コミット → UI → ロゴ → 配布物)。公開の前提 (実装ブロッカーではない)
2. **v1.8 の残り**: 通し計測 (`playtest_full.gd`・通常+難易度別) でコイン回収量・ボスTTK・撃破数 (v1.7 比) を実測 →
   コスト・難易度倍率・`ELITE_SCALE`/`FINAL_BOSS_SCALE`・射程を確定して SPEC に書き戻す (P12/P19 と同じ流儀)
3. BGM の耳確認 (ボス切替の自然さ・ループ継ぎ目・ゲーム中の抑え具合) — ユーザー確認
4. D47 (最低距離160)・D57 (破片48) の数値確定 (v1.7 分・未消化)
5. 商用化 (YouTube 収益化・販売) を検討する時点で 1min.ai サポート確認を再実施 (Suno を特に。SPEC §37.1)
6. 実装ブロッカー: なし

- 補足 (2026-09-28): Godot エディタ保存で落ちていた Web `include_filter="*.txt"`・`[autoload]` 行は復元し、ユーザー設定 (フォント行・`stretch/aspect="expand"`) と `main.tscn` の正規化差分は P26 でコミット済み (stretch はユーザー設定の `expand` を採用・SPEC §35.3 に注記)。
  以後のヘッドレス実行でも `[autoload]` 行が落ちることがある → コミット前に確認して復元 (`git checkout -- project.godot` は使わない)。

---

## 7. 公開前の準備 (ライセンス・クレジット) — 2026-09-28 監査

> IDEA.md「GitHub等、パブリック公開するときの注意点」を実査で確定・拡張したもの。GitHub 公開 / exe・Web 配布の前に消化する。
> 監査方法: 全資産の列挙・上流との blob SHA 照合・書き出し pck の走査・素材メタデータ・各ライセンスの一次情報 (Godot 公式ドキュメント / 配布元 LICENSE / 各サービスの規約)。
> ※ 法的助言ではない。公開形態 (無償/有償) で判断が変わるため、最終判断は必要に応じて専門家に確認する。

### 7.1 監査結果サマリ

**ライセンス文はリポジトリにも書き出し物にも存在しない** (LICENSE/COPYRIGHT 系ファイル 0 件、pck 内に MIT/OFL/COPYRIGHT の文字列 0 件)。
スタッフロールのクレジットは「誰が作ったか」の表示であり、MIT/OFL が要求する「ライセンス文の同梱」の代わりにはならない。

| 対象 | ライセンス | 必要な対応 | 現状 |
|---|---|---|---|
| Godot Engine 4.7.2 | MIT | **ライセンス文**を配布物に同梱 or ゲーム内表示 (クレジットに `godotengine.org/license` リンクでも公式が許容)。サードパーティ分は `COPYRIGHT.txt` を同梱 | ❌ 未対応 |
| Godot ロゴ (icon.svg・起動スプラッシュ・Web favicon) | CC BY 4.0 (© 2017 Andrea Calabró) | 帰属表示 or 自前画像へ差し替え (**差し替え推奨**) | ❌ 未対応 |
| `font/NotoSansMonoCJKjp-VF.otf` | SIL OFL 1.1 | OFL 本文の同梱。フォント単体の販売は不可 (ゲーム同梱は可) | ❌ 未対応・未コミット |
| `addons/godot_mcp` | MIT (© 2026 Youichi Uda) | MIT 文の同梱。有料サーバ部分は非同梱で OK | ❌ 未対応 |
| Suno 4曲 (主題歌+BGM 3) | 1min.ai 経由 | クレジット済み ✅。有償展開するなら商用可否を 1min.ai に確認 | ⚠ 条件付き |
| ElevenLabs SFX 20音 | 要確認 | 生成経路とプランの確定 (無料プラン = 商用不可・帰属必須) | ⚠ 要確認 |
| 画像 (スプライト/タイル/タイトル画) | gpt-image-2 (OpenAI) via 1min-image | 低リスク。任意でクレジットを正確化 | ⚠ 軽微 |
| プロジェクト自身の LICENSE | — | 公開前に決定 (未設定 = 全権利留保) | ❌ なし |

### 7.2 根拠 (一次情報の要約)

- **Godot**: 公式「ライセンスの遵守」— MIT の唯一の要件はライセンス文を配布物のどこかに含めること。方法はクレジット画面 / ライセンス画面 / ログ出力 / `godotengine.org/license` へのリンクのいずれか1つでよい。サードパーティ分は `COPYRIGHT.txt` を配布物に含める (`GODOT_COPYRIGHT.txt` 等へのリネーム可・公式推奨)。
- **ロゴ**: Godot の `misc/logo` は CC-BY-4.0。`icon.svg` は既定ロゴのまま (exe アイコン・Web favicon 128×128 に使用)。起動スプラッシュも既定の Godot ロゴ (Web 書き出しの 800×600 スプラッシュ画像で確認)。
- **フォント**: blob SHA `006ca0e8…9f` が notofonts/noto-cjk `Sans/Variable/OTF/Mono/NotoSansMonoCJKjp-VF.otf` と一致 = **無改変** (名称表に「© 2014-2021 Adobe」「OFL 1.1」v2.004)。改変なしのため RFN (Reserved Font Name) の制約なし。
- **アドオン**: 上流 LICENSE に「本ライセンスは addons/godot_mcp/ に適用。TypeScript サーバはプロプライエタリとして別配布」と明記 → アドオン部の再配布は可。ローカルは v1.16.0 (上流 master は 1.17.1) で独自改変なし。**ただし書き出し pck にアドオンコードが同梱される** (`addons/godot_mcp` の文字列が 150 箇所。autoload 3 つは editor ガードで実行時は無効化される)。
- **音**: mp3 の ID3 TXXX に `made with suno; created=…; id=…` (主題歌 `5a30aa11…` / title `23f8161c…` / game `83c89abf…` / boss `d7d34175…`) = 全曲 Suno 生成の証跡。1min.ai の料金ページは "Commercial use" を訴求するが、TOS には出力の権利条項が見当たらない。
- **画像**: raw PNG と `ui/title_art.png` に C2PA (caBX チャンク、中身に OpenAI/gpt の記載) → 実際のモデルは **gpt-image-2**。加工済みスプライトにはメタデータは残らない。
- **SFX**: 現行 1min-image の音声モデル一覧は google-tts / qwen3-tts / openai-tts / suno のみ (ElevenLabs なし) → 直接 ElevenLabs で生成した可能性が高い。
- 補足: AI 生成物は人間の著作権が及ばない可能性がある → 自前 LICENSE では画像・音声について独占権を主張しない注記が無難。

### 7.3 対応チェックリスト

**A. リポジトリに追加 (公開する場合)**

- [ ] `THIRD_PARTY_NOTICES.md` — Godot MIT 文 + ロゴ帰属 + Noto OFL + MCP Pro MIT + 生成クレジット (Suno / ElevenLabs / gpt-image-2 via 1min-image)
- [ ] `GODOT_COPYRIGHT.txt` — Godot 公式から取得 (配布物にも同梱)
- [ ] `addons/godot_mcp/LICENSE` — 上流の MIT 文をそのまま
- [ ] `font/LICENSE.txt` — noto-cjk `Sans/LICENSE` (OFL 本文)
- [ ] `font/OFL.txt` - NotoColorEmojiの配布物(Noto_Color_Emoji.zip)同梱のライセンス文
- [ ] `LICENSE` — プロジェクト本体のライセンスを決定
- [ ] `font/` をコミットするか決定 (30MB。コミットした時点で OFL 同梱義務が発生)

**B. ゲーム内表示**

- [ ] オプションに「ライセンス」欄 (IDEA.md の予定項目) — Godot MIT 文 or `godotengine.org/license` リンク / OFL 文 / (アドオンを書き出しに残すなら) MIT 文 / (ロゴを残すなら) 帰属
- [ ] スタッフロールは既存クレジットを維持 (任意: 「Google Image」→ gpt-image-2 に正確化)

**C. 配布物・書き出し**

- [ ] 配布物 (zip) にライセンス文を同梱 — ※ `include_filter="*.txt"` + `embed_pck=true` は pck 内に入り**ユーザーから見えない**ため、法的同梱に使わない
- [ ] 判断: 書き出しに addons を含める (現状入る) か除外するか。含める場合はゲーム内ライセンスにも MIT 文を追加 (除外は autoload 3 つの扱いが絡むため、クレジット追加の方が簡単)
- [ ] 任意: `icon.svg` 差し替え + ブートスプラッシュ変更 / Windows 書き出しの `application/copyright` 記入 (現在空)

**D. 確認事項 (ユーザー判断)**

- [ ] ElevenLabs の生成経路とプラン (無料プランなら「elevenlabs.io」帰属 + 非商用)
- [ ] 1min.ai の商用条件 (有償販売・広告付き公開をする場合。サポートに確認して記録を残す)
- [ ] 歌詞の作者 (人間が書いたならクレジット追記を検討)

### 7.4 完了条件

- リポジトリ / exe / Web の全公開物に必要なライセンス文・帰属が含まれ、ゲーム内から参照できる
- ロゴは差し替え済み or 帰属表示済み
- 7.3-D の確認事項 3 件が解消している

### 7.5 v1.9 設計での確定 (2026-09-28・SPEC §37 との対応)

| §7 の項目 | 確定 | 対応 D |
|---|---|---|
| A. THIRD_PARTY_NOTICES.md | 内容を SPEC §37.3 で確定 (6節・ロゴ帰属なし) | D85 |
| A. GODOT_COPYRIGHT.txt / addons LICENSE / font LICENSE・OFL / font 本体 | すべてコミットする (§37.4) | D86 |
| A. LICENSE | MIT・© 2026 yoshuki (§37.2) | D84 |
| B. オプション「ライセンス」欄 | 全画面スクロールページ `ui/license_ui` (§37.5) | D87 |
| B. スタッフロールのクレジット | 「1min.ai」「gpt-image-2」に正確化 (§37.6) | D88 / D89 |
| C. 配布物のライセンス同梱 | リリース zip / Web フォルダの構成を §37.8 で確定 (pck 内包は法的同梱に使わない) | D91 |
| C. addons を書き出しに含めるか | **含める** (現状どおり) + ゲーム内ライセンスに MIT 文を表示 (§37.3-4) | D87 |
| C. icon.svg 差し替え・スプラッシュ・Windows メタデータ | 差し替え + スプラッシュ新設 + メタデータ記入 (§37.7・§37.8) | D90 / D91 |
| D. ElevenLabs の経路とプラン | 1min.ai 有料プラン (PRO) 経由 (ユーザー確認済み・調査メモ) | D92 |
| D. 1min.ai の商用条件 | 調査メモの結論 (全プラン商用可宣言・Suno は上流条件の注意つき)。今回の非商用公開では不要、収益化時に再確認 | D92 |
| D. 歌詞の作者 | クレジットどおり Suno 生成 (作詞含む) として扱う | D92 |

> 調査メモ: `<external-notes>/1min-ai-license-research-2026-09-28.md` (リポジトリ外)・セッション 20260928_170646_d45e81。
> 完了条件は §7.4 のまま (P26 の完了条件)。
