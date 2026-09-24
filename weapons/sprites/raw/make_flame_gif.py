"""フレイムスロワーの実機GIFを作る"""
import os
from PIL import Image

BASE = "<repo-root>"
SHOTS = os.path.join(BASE, "tmp_shots")
OUT = os.path.join(BASE, "weapons", "sprites", "raw")
os.makedirs(OUT, exist_ok=True)

frames = []
for k in range(5):
    im = Image.open(os.path.join(SHOTS, f"flame_{k}.png")).convert("RGB")
    c = im.crop((576 - 170, 324 - 120, 576 + 290, 324 + 120))
    frames.append(c.resize((c.width * 2, c.height * 2), Image.NEAREST))
p = os.path.join(OUT, "flame_ingame.gif")
frames[0].save(p, save_all=True, append_images=frames[1:], duration=200, loop=0, disposal=2)
print("wrote", p, frames[0].size)
