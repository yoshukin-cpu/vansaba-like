"""AI生成シート → Godot用タイル/スプライトに加工する (P10)。

- ground_sheet.png (6x3=18セル, 不透明) → world/sprites/ground_0..17.png (48x48)
- tree_sheet.png (3セル, マゼンタ背景)   → world/sprites/ob_0..2.png (48x144, 下端揃え)
- prop_sheet.png (3x2=6セル, マゼンタ背景) → world/sprites/ob_3..4.png (岩 48x48/48x72)
                                        → objects/sprites/chest.png, chest_open.png, bomb.png, coin.png

実行: python world/sprites/raw/process_tiles.py
"""
import os
from PIL import Image

RAW = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(RAW)))
WSPR = os.path.join(ROOT, "world", "sprites")
OSPR = os.path.join(ROOT, "objects", "sprites")

TILE = 48
TREE_H = 144


def cells(img, cols, rows):
    w, h = img.size
    cw, ch = w // cols, h // rows
    for r in range(rows):
        for c in range(cols):
            yield img.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))


def key_magenta(img, thr=110):
    """外周から連結したマゼンタ背景だけを透過にする + 縁のデスピル。"""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    # 背景色 = 外周3pxの中央値
    samples = []
    for x in range(w):
        for y in list(range(3)) + list(range(h - 3, h)):
            samples.append(px[x, y][:3])
    for y in range(h):
        for x in list(range(3)) + list(range(w - 3, w)):
            samples.append(px[x, y][:3])
    samples.sort(key=lambda c: c[0] + c[1] + c[2])
    bg = samples[len(samples) // 2]

    def is_bg(c):
        return abs(c[0] - bg[0]) + abs(c[1] - bg[1]) + abs(c[2] - bg[2]) < thr

    # 外周から連結している背景だけを消す (連結成分)
    seen = bytearray(w * h)
    stack = []
    for x in range(w):
        stack.append((x, 0))
        stack.append((x, h - 1))
    for y in range(h):
        stack.append((0, y))
        stack.append((w - 1, y))
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        i = y * w + x
        if seen[i]:
            continue
        if not is_bg(px[x, y][:3]):
            continue
        seen[i] = 1
        px[x, y] = (0, 0, 0, 0)
        stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

    # デスピル (半透明のマゼンタ縁を抑える)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0 and min(r, b) - g > 30:
                k = (min(r, b) - g) // 2
                px[x, y] = (max(0, r - k), g, max(0, b - k), a)
    return img


def content_bbox(img, thr=8):
    a = img.split()[3]
    return a.point(lambda v: 255 if v > thr else 0).getbbox()


def _dominant(img, quant=16):
    """最頻色 (量子化して数える) を返す。タイルの下地色の推定に使う。"""
    counts = {}
    for c in img.convert("RGB").getdata():
        k = (c[0] // quant, c[1] // quant, c[2] // quant)
        counts[k] = counts.get(k, 0) + 1
    best = max(counts.items(), key=lambda kv: kv[1])[0]
    return tuple(int(v * quant + quant // 2) for v in best)


def _shift_to(img, target):
    """タイルの下地 (最頻色) が target になるよう全画素を平行移動する。"""
    cur = _dominant(img)
    d = tuple(target[k] - cur[k] for k in range(3))
    px = img.convert("RGB").load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            px[x, y] = (
                max(0, min(255, r + d[0])),
                max(0, min(255, g + d[1])),
                max(0, min(255, b + d[2])),
            )
    return img.convert("RGB")


def fit_bottom(img, canvas_w, canvas_h, max_w, max_h, bottom_margin=0, center=False):
    """内容を拡大縮小してキャンバスに収める。既定は下端揃え (足元を合わせる)。"""
    bb = content_bbox(img)
    if bb is None:
        return Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    obj = img.crop(bb)
    scale = min(max_w / obj.width, max_h / obj.height)
    nw, nh = max(1, int(round(obj.width * scale))), max(1, int(round(obj.height * scale)))
    obj = obj.resize((nw, nh), Image.LANCZOS)
    # アルファを二値化 (ドット絵らしさ)
    px = obj.load()
    for y in range(nh):
        for x in range(nw):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= 96 else 0)
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    ox = (canvas_w - nw) // 2 if center else (canvas_w - nw) // 2
    oy = (canvas_h - nh) // 2 if center else (canvas_h - nh - bottom_margin)
    canvas.paste(obj, (ox, oy), obj)
    return canvas


def main():
    os.makedirs(WSPR, exist_ok=True)
    os.makedirs(OSPR, exist_ok=True)

    # --- 地面: 6x3 等分割 → 縁を少し内側に切って 48x48 ---
    g = Image.open(os.path.join(RAW, "ground_sheet.png")).convert("RGB")
    tiles = []
    for i, c in enumerate(cells(g, 6, 3)):
        inset_x = int(c.width * 0.05)
        inset_y = int(c.height * 0.05)
        c = c.crop((inset_x, inset_y, c.width - inset_x, c.height - inset_y))
        tiles.append(c.resize((TILE, TILE), Image.LANCZOS))

    # 草原4種の基準色 (最頻色の平均) に、装飾タイルの下地を寄せる
    base_grass = _dominant(tiles[0])
    for t in tiles[1:4]:
        base_grass = tuple((base_grass[k] + _dominant(t)[k]) // 2 for k in range(3))
    for i in range(12, 18):
        tiles[i] = _shift_to(tiles[i], base_grass)
    print("grass base:", base_grass)

    for i, t in enumerate(tiles):
        t.save(os.path.join(WSPR, "ground_%d.png" % i))
    print("ground: 18 tiles ->", WSPR)

    # --- 木: 3セル → 48x144 下端揃え ---
    t = key_magenta(Image.open(os.path.join(RAW, "tree_sheet.png")))
    for i, c in enumerate(cells(t, 3, 1)):
        out = fit_bottom(c, TILE, TREE_H, TILE, TREE_H)
        out.save(os.path.join(WSPR, "ob_%d.png" % i))
    print("trees: 3 ->", WSPR)

    # --- 小物: 3x2 → 岩2 (ob_3/ob_4) + 宝箱/爆弾/コイン ---
    p = key_magenta(Image.open(os.path.join(RAW, "prop_sheet.png")))
    prop = list(cells(p, 3, 2))
    # 岩 (小): セル下端 4px を空けて 48x48
    fit_bottom(prop[0], TILE, TILE, 44, 40, bottom_margin=4).save(os.path.join(WSPR, "ob_3.png"))
    # 岩 (大): 48x72
    fit_bottom(prop[1], TILE, 72, 46, 66, bottom_margin=2).save(os.path.join(WSPR, "ob_4.png"))
    # 宝箱 (閉/開): 48x48
    fit_bottom(prop[2], TILE, TILE, 42, 40, bottom_margin=4).save(os.path.join(OSPR, "chest.png"))
    fit_bottom(prop[3], TILE, TILE, 42, 42, bottom_margin=4).save(os.path.join(OSPR, "chest_open.png"))
    # 爆弾: 48x48
    fit_bottom(prop[4], TILE, TILE, 36, 36, bottom_margin=6).save(os.path.join(OSPR, "bomb.png"))
    # コイン: 32x32 (中央)
    fit_bottom(prop[5], 32, 32, 28, 28, center=True).save(os.path.join(OSPR, "coin.png"))
    print("props: rocks -> %s / chest,bomb,coin -> %s" % (WSPR, OSPR))


if __name__ == "__main__":
    main()
