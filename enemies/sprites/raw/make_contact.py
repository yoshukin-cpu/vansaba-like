"""処理済みスプライトの確認用コンタクトシートを作る (中央アンカー、拡大表示)"""
import os
import sys
from PIL import Image, ImageDraw

d = sys.argv[1]
prefix = sys.argv[2]
names = sys.argv[3].split(",")
S = int(sys.argv[4]) if len(sys.argv) > 4 else 6
out_name = sys.argv[5] if len(sys.argv) > 5 else "contact.png"
cols = int(sys.argv[6]) if len(sys.argv) > 6 else 5

imgs = []
for n in names:
    p = os.path.join(d, f"{prefix}_{n}.png")
    if not os.path.exists(p):
        print("missing:", p)
        continue
    imgs.append((n, Image.open(p).convert("RGBA")))

if not imgs:
    sys.exit("no images")

cw = max(i.size[0] for _, i in imgs) * S
ch = max(i.size[1] for _, i in imgs) * S
rows = (len(imgs) + cols - 1) // cols
out = Image.new("RGBA", (cw * cols, (ch + 30) * rows), (28, 28, 38, 255))
dr = ImageDraw.Draw(out)
for i, (n, im) in enumerate(imgs):
    big = im.resize((im.width * S, im.height * S), Image.NEAREST)
    x = (i % cols) * cw
    y = (i // cols) * (ch + 30)
    out.paste(big, (x + (cw - big.width) // 2, y + 30), big)
    dr.text((x + 8, y + 8), f"{n} ({im.width}x{im.height})", fill=(240, 240, 250, 255))
    dr.line([(x, 0), (x, out.height)], fill=(80, 80, 100, 255), width=1)
out.save(os.path.join(d, "raw", out_name))
print("wrote", os.path.join(d, "raw", out_name), out.size)
