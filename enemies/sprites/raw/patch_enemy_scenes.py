#!/usr/bin/env python3
"""敵シーン(.tscn)に sprite_path と scale を一括で設定する。
ルートノードのプロパティブロック内の該当行を置換/追加する。
"""
import os
import re

DIR = "<repo-root>/enemies"

CFG = {
    "slime": ("res://enemies/sprites/enemy_slime.png", 0.8),
    "bat": ("res://enemies/sprites/enemy_bat.png", 0.8),
    "goblin": ("res://enemies/sprites/enemy_goblin.png", 1.0),
    "archer": ("res://enemies/sprites/enemy_archer.png", 1.0),
    "wolf": ("res://enemies/sprites/enemy_wolf.png", 1.1),
    "golem": ("res://enemies/sprites/enemy_golem.png", 1.5),
    "splitter": ("res://enemies/sprites/enemy_splitter.png", 1.1),
    "sniper": ("res://enemies/sprites/enemy_sniper.png", 1.0),
    "swarm": ("res://enemies/sprites/enemy_swarm.png", 0.7),
    "knight": ("res://enemies/sprites/enemy_knight.png", 1.3),
    "splitmini": ("res://enemies/sprites/enemy_splitter.png", 0.6),
}

for name, (path, scale) in CFG.items():
    fp = os.path.join(DIR, f"{name}.tscn")
    with open(fp, "r", encoding="utf-8") as f:
        text = f.read()
    lines = text.split("\n")

    # ルートノード([node ... instance=ExtResource])のブロック範囲を探す
    start = None
    for i, ln in enumerate(lines):
        if ln.startswith("[node ") and "parent=" not in ln:
            start = i
            break
    if start is None:
        print(f"  SKIP {name}: ルートノードが見つからない")
        continue
    end = len(lines)
    for j in range(start + 1, len(lines)):
        if lines[j].startswith("["):
            end = j
            break

    block = lines[start:end]
    new_block = []
    has_sprite = False
    has_scale = False
    for ln in block:
        if ln.startswith("sprite_path"):
            new_block.append(f'sprite_path = "{path}"')
            has_sprite = True
        elif ln.startswith("scale ="):
            new_block.append(f"scale = Vector2({scale}, {scale})")
            has_scale = True
        else:
            new_block.append(ln)
    # ブロック末尾の空行の手前に追記
    tail = []
    while new_block and new_block[-1] == "":
        tail.append(new_block.pop())
    if not has_sprite:
        new_block.append(f'sprite_path = "{path}"')
    if not has_scale and scale != 1.0:
        new_block.append(f"scale = Vector2({scale}, {scale})")
    new_block.extend(tail)

    lines[start:end] = new_block
    with open(fp, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"  updated {name}.tscn: sprite_path, scale={scale}")
