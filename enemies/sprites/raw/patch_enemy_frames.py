#!/usr/bin/env python3
"""敵シーン(.tscn)の sprite_path を frames_path + anim_fps に置き換える"""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DIR = str(ROOT / "enemies")

# (フレームのリソース名, アニメ速度fps) — 敵の種類ごとに変える
CFG = {
    "slime": ("slime_frames.tres", 3.0),
    "bat": ("bat_frames.tres", 12.0),
    "goblin": ("goblin_frames.tres", 5.0),
    "archer": ("archer_frames.tres", 4.0),
    "wolf": ("wolf_frames.tres", 9.0),
    "golem": ("golem_frames.tres", 2.5),
    "splitter": ("splitter_frames.tres", 4.0),
    "sniper": ("sniper_frames.tres", 4.0),
    "swarm": ("swarm_frames.tres", 14.0),
    "knight": ("knight_frames.tres", 5.0),
    "splitmini": ("splitter_frames.tres", 8.0),
    "boss_golem_king": ("boss_golem_king_frames.tres", 2.0),
    "boss_void_emperor": ("boss_void_emperor_frames.tres", 3.0),
}

for name, (tres, fps) in CFG.items():
    fp = os.path.join(DIR, f"{name}.tscn")
    with open(fp, "r", encoding="utf-8") as f:
        lines = f.read().split("\n")
    out = []
    replaced = False
    for ln in lines:
        if ln.startswith("sprite_path"):
            out.append(f'frames_path = "res://enemies/sprites/{tres}"')
            out.append(f"anim_fps = {fps}")
            replaced = True
        else:
            out.append(ln)
    if not replaced:
        print(f"  WARN {name}: sprite_path 行が見つからない")
        continue
    with open(fp, "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    print(f"  updated {name}.tscn: {tres} @ {fps}fps")
