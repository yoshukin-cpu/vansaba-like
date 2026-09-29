"""left/right の向きを機械的に判定する
旧v1フレーム(実機で向き確認済み)と比較し、
  diff(新, 旧) と diff(新, 旧の左右反転) のどちらが小さいかで判定する。
"""
import os
from pathlib import Path
import subprocess
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
BASE = str(ROOT / "player" / "sprites")
OLD = os.path.join(BASE, "raw", "old_v1")
os.makedirs(OLD, exist_ok=True)

# git から旧フレームを取り出す (97b0260 の親 = v1 フレーム)
for d in ["left", "right"]:
    for i in range(4):
        name = f"player_walk_{d}_{i}.png"
        blob = subprocess.run(
            ["git", "show", f"HEAD~1:player/sprites/{name}"],
            cwd=str(ROOT), capture_output=True).stdout
        with open(os.path.join(OLD, name), "wb") as f:
            f.write(blob)
print("旧v1フレームを展開:", len(os.listdir(OLD)), "件")


def load(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.int16)


def diff(a, b):
    # どちらかに絵がある領域だけを比較
    mask = (a[:, :, 3] > 0) | (b[:, :, 3] > 0)
    d = np.abs(a - b).sum(axis=2).astype(np.float32)
    return float(d[mask].mean())


print()
print("=== 新フレーム vs 旧v1フレーム (実機で向き確認済み) ===")
print("小さい方に近い = その向き")
for d in ["left", "right"]:
    for i in range(4):
        new = load(os.path.join(BASE, f"player_walk_{d}_{i}.png"))
        old = load(os.path.join(OLD, f"player_walk_{d}_{i}.png"))
        old_flip = np.fliplr(old)
        dn = diff(new, old)
        df = diff(new, old_flip)
        verdict = "同じ向き" if dn < df else "逆を向いている(反転と一致)"
        print(f"  new_{d}_{i}: 旧と {dn:7.1f} / 旧の反転と {df:7.1f}  -> {verdict}")

print()
print("=== 新フレーム同士: left と right は鏡像か? ===")
for i in range(4):
    nl = load(os.path.join(BASE, f"player_walk_left_{i}.png"))
    nr = load(os.path.join(BASE, f"player_walk_right_{i}.png"))
    d_same = diff(nl, nr)
    d_mirror = diff(nl, np.fliplr(nr))
    verdict = "鏡像(左右が逆を向いている)" if d_mirror < d_same else "同じ向きを向いている(左右が未分離)"
    print(f"  f{i}: left vs right {d_same:7.1f} / left vs 反転right {d_mirror:7.1f} -> {verdict}")
