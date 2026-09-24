"""敵・ボス・弾の全スプライトを1枚のプレビュー画像にまとめる"""
import os
from PIL import Image, ImageDraw

BASE = "<repo-root>"
SP = os.path.join(BASE, "enemies", "sprites")
OUT = os.path.join(SP, "raw", "preview")
os.makedirs(OUT, exist_ok=True)
S = 4

enemies = ["slime", "bat", "goblin", "archer", "wolf", "golem",
           "splitter", "sniper", "swarm", "knight"]
bosses = ["boss_golem_king", "boss_void_emperor"]
projs = ["proj_bolt", "proj_homing", "proj_orb", "proj_bomb"]

items = []  # (label, path, scale)
for n in enemies:
    items.append((n, os.path.join(SP, f"enemy_{n}.png"), S))
for n in bosses:
    items.append((n, os.path.join(SP, f"{n}.png"), S // 2))
for n in projs:
    items.append((n, os.path.join(SP, "projectiles", f"{n}.png"), S * 3))

cell = 128 * S
cols = 8
rows = (len(items) + cols - 1) // cols
out = Image.new("RGB", (cell * cols, (cell + 28) * rows), (26, 26, 34))
dr = ImageDraw.Draw(out)
for i, (label, path, sc) in enumerate(items):
    im = Image.open(path).convert("RGBA")
    big = im.resize((im.width * sc, im.height * sc), Image.NEAREST)
    x = (i % cols) * cell
    y = (i // cols) * (cell + 28)
    out.paste(big, (x + (cell - big.width) // 2, y + 28 + (cell - big.height) // 2), big)
    dr.text((x + 8, y + 8), f"{label}", fill=(240, 240, 250))
    dr.rectangle([x, y + 28, x + cell - 1, y + 28 + cell - 1], outline=(70, 70, 90))
p = os.path.join(OUT, "all_monsters_preview.png")
out.save(p)
print("wrote", p, out.size)
