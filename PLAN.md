# 実装計画 v1.0

> 前提: SPEC.md v1.0 / Godot 4.7.2 / 現状は `project.godot` + `icon.svg` のみ、main_scene未設定。
> 方針: データ駆動・仮素材・小さく動くものを反復。Editor toolsで構築、Runtime toolsで検証。

## 0. ゴール・マイルストーン

- M1 移動+カメラで歩ける (P0)
- M2 武器で敵を倒してXPが出る (P1-P2)
- M3 レベルアップ3択ループが回る (P3)
- M4 10分波形+10敵+20カードが揃う (P4)
- M5 ボス2体+勝敗が付く (P5)
- M6 300体でも60fps近く保つ (P6-P7)

## 1. ファイル構成案

```
res://
  main.tscn (Main: World + HUD + Managers)
  project.godot (input追加, stretch設定)
  player/player.tscn, player.gd
  enemies/enemy.tscn, enemy.gd
  weapons/weapon_base.gd + 6種 (spin, shot, homing, lightning, flame, bomb)
  projectiles/projectile.tscn, projectile.gd (+pool)
  pickups/xp_gem.tscn, xp_gem.gd (+pool)
  systems/spawn_director.gd, game_manager.gd, audio_manager.gd
  data/cards_db.gd, enemies_db.gd, waves_db.gd
  ui/hud.tscn, levelup_ui.tscn, title.tscn, result_ui.tscn
```

- Collisions: layersはSPEC §2案。最初は `move_and_slide` + `Area2D` で検出。
- Autoload: `GameManager` のみ。MCP系Autoloadは既存のため触らない。

## 2. フェーズ計画

### P0 基盤 [M1]

- `set_project_setting` で input actions追加: move_*(WASD+矢印+Joypad), aim (右スティック), pause, confirm
- display stretch `canvas_items`, viewport 1152x648維持
- Main/Player/Camera/背景グリッド作成。Player: CharacterBody2D, Speed 230
- 検証: `play_scene` → `simulate_key(WASD 0.5s)` + ジョイパッド入力があれば `simulate_action` → `get_game_screenshot` で移動確認

### P1 攻撃コア [M2前半]

- `WeaponBase` (CD・Lvテーブル・照準取得IF) + C02ストレート + C01スピン の2種先行
- 照準: 右スティック>マウス>最寄り>移動方向 (`find_nodes_by_type`相当をgame scriptで実装)
- 検証: ダミー敵配置 → `capture_frames` で弾が出てHPが減ることを `monitor_properties` で確認

### P2 敵コア [M2後半]

- 共通 `Enemy.tscn/gd` (HP・速度・接触dmg・ノックバック・フラッシュ) + data注入
- 先行2種: E01スライム、E02コウモリ。接触ダメージ+無敵0.5s、撃破でXP宝石(1)落下・マグネット回収
- 検証: スポーン→接触でHP減→撃破でXP+1を確認、`assert_node_state`活用

### P3 成長ループ [M3]

- XP管理・Lv式 `10+(Lv-1)*8`、LevelUp UI (3枚・ポーズ・選択)
- 先行カード5種のみ: C01/C02/C07/C15/C16 でループ成立を優先
- Title/HUD最小 (HP/XP/Timer) 追加
- 検証: XP付与のgame scriptで強制LvUp → UI表示 → 選択でステータス変化をassert

### P4 量産 [M4]

- 残り武器4種 + 強化/生存カード全20種を `cards_db` に実装
- 残り敵8種を data+分岐行動 (遠隔・突進・分裂・群れ) で実装
- `SpawnDirector` + `waves_db` でSPEC §11の波形実装、エリート対応
- 検証: 時間加速scriptで各wave出現確認、LvUpプール枯渇時のフォールバック確認

### P5 ボス・勝敗 [M5]

- B01 (突進+召喚+衝撃波)、B02 (弾幕+狙撃+召喚) をEnemy拡張で実装
- GameManagerに timer/ボス警告/勝敗/リトライ/ポーズ追加、Result UI
- 検証: 時間スキップで5:00/10:00ボス出現→撃破でClear、HP0でGameOverを確認

### P6 演出・最適化

- ヒットフラッシュ・ノックバック・撃破パーティクル・ダメージ数字(プール・任意OFF)
- Object pooling (弾・宝石・数字・敵)、同時250体目標、`get_editor_performance` + `get_performance_monitors` 計測
- 目安: 300体でFPS>50出なければ、衝突を簡略化・描画を削減

### P7 QA・仕上げ

- 通しプレイ: 0→10分 (倍速script併用)、操作両対応 (キー+パッド) 確認
- `run_test_scenario` / `run_stress_test` で回帰、export presets確認 (`list_export_presets`)
- SPECとの差分を修正、チューニング (XP曲線・HP倍率)

## 3. 並行可能タスク

- UI (HUD/LevelUp/Title) はP1-P3と並行可
- SE/演出はP5以降で差し替え可 (仮素材のためブロッカーにしない)
- `subagent` で分担例: (a) weapons実装 (b) enemies実装 (c) UI実装

## 4. リスク・対策

| リスク | 対策 |
|---|---|
| 敵大量で重い | pooling + 同時上限 + Area数削減、早期にP6計測 |
| 双入力の不整合 | 照準優先度を固定し、PCのみ/パッドのみでもクリア可にする |
| カード20種のバグ | data駆動+フォールバック、MAX除外抽選の単体テスト |
| ボスが倒せない/易しすぎる | HP/弾幕を定数化し、game scriptでスキップ検証して調整 |
| scope肥大 | v1対象外 (仮想スティック・セーブ・リロール) は入れない |

## 5. 検証コマンド (godot-mcp-pro)

- 構築: `create_scene`, `batch_add_nodes`, `create_script`, `attach_script`, `save_scene`
- 実行: `play_scene` → `simulate_key/mouse_click/action` → `get_game_screenshot/capture_frames/monitor_properties/assert_node_state` → `stop_scene`
- 調査: `get_scene_tree`, `read_script`, `get_editor_errors`, `get_output_log`

## 6. 次アクション提案

1. P0開始: project settings + Main/Player/Camera (仮素材)
2. P1-P2でM2到達を最優先 (遊べる核)
3. P3でループ完成後に量産 (P4以降)

着手指示があればP0から実装開始します。
