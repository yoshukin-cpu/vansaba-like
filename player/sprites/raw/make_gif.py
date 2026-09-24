#!/usr/bin/env python3
"""スプライトフレームから確認用GIFを作る。
使い方: python make_gif.py <sprites_dir>
"""
import os
import sys

from PIL import Image

BG = (24, 24, 32, 255)
SCALE = 3
DIRS = ["down", "left", "right", "up"]


def make_gif(sprites_dir, prefix, anim, frames_per_dir, duration, out_name):
    frames = []
    for i in range(frames_per_dir):
        strip = Image.new("RGBA", (64 * len(DIRS), 64), BG)
        for j, d in enumerate(DIRS):
            path = os.path.join(sprites_dir, f"{prefix}_{d}_{i}.png")
            im = Image.open(path).convert("RGBA")
            strip.paste(im, (j * 64, 0), im)
        frames.append(strip.resize(
            (strip.width * SCALE, strip.height * SCALE), Image.NEAREST))
    out = os.path.join(sprites_dir, out_name)
    frames[0].save(out, save_all=True, append_images=frames[1:],
                   duration=duration, loop=0, disposal=2)
    print(f"wrote {out} ({frames_per_dir} frames, {frames[0].size[0]}x{frames[0].size[1]})")


if __name__ == "__main__":
    sp = sys.argv[1] if len(sys.argv) > 1 else "."
    make_gif(sp, "player_walk", "walk", 4, 125, "preview_walk.gif")
    make_gif(sp, "player_idle", "idle", 2, 400, "preview_idle.gif")
