"""敵の2フレームアニメ(前後)をまとめた確認GIFを作る"""
import os
from PIL import Image

BASE = "<repo-root>/enemies/sprites"
OUT = os.path.join(BASE, "raw", "preview")
os.makedirs(OUT, exist_ok=True)
NAMES = ["slime", "bat", "goblin", "archer", "wolf", "golem", "splitter", "sniper", "swarm", "knight"]
S = 3
CELL = 48 * S

frames = []
for variant, label in [("0", "front f1"), ("1", "front f2"), ("b0", "back f1"), ("b1", "back f2")]:
    row = Image.new("RGB", (CELL * len(NAMES), CELL), (26, 26, 34))
    for i, n in enumerate(NAMES):
        im = Image.open(os.path.join(BASE, f"enemy_{n}_{variant}.png")).convert("RGBA")
        big = im.resize((im.width * S, im.height * S), Image.NEAREST)
        row.paste(big, (i * CELL + (CELL - big.width) // 2,
                        (CELL - big.height) // 2), big)
    frames.append(row)

out = os.path.join(OUT, "enemy_anim_preview.gif")
frames[0].save(out, save_all=True, append_images=frames[1:], duration=350, loop=0, disposal=2)
print("wrote", out, frames[0].size)
