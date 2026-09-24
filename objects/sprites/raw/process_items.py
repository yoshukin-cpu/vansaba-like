"""アイテムシート (2x2) → objects/sprites/item_{heart,star,magnet,sword}.png (48x48)。

実行: python objects/sprites/raw/process_items.py
"""
import os
import sys

RAW = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(RAW)))
sys.path.insert(0, os.path.join(ROOT, "world", "sprites", "raw"))
from PIL import Image
from process_tiles import key_magenta, cells, content_bbox, fit_bottom  # noqa

RAW = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(RAW)))
OUT = os.path.dirname(RAW)
NAMES = ["heart", "star", "magnet", "sword"]


def main():
    sheet = key_magenta(Image.open(os.path.join(RAW, "item_sheet.png")))
    for i, c in enumerate(cells(sheet, 2, 2)):
        out = fit_bottom(c, 48, 48, 36, 36, bottom_margin=6)
        out.save(os.path.join(OUT, "item_%s.png" % NAMES[i]))
        bb = content_bbox(out)
        print("item_%s: bbox=%s" % (NAMES[i], bb))
    print("items ->", OUT)


if __name__ == "__main__":
    main()
