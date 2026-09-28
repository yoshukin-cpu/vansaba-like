#!/usr/bin/env python3
"""icon.svg を生成する (v1.9・P26・SPEC §37.7 / D90)。

「月夜に囲まれる主人公」のタイトル画 (ui/title_art.png) を 32×32 に要約した
ピクセルアート。32 グリッド × 8px = 256×256 の viewBox に rect で描く。
再生成: python tools/make_icon.py  (リポジトリルートで)
"""
from __future__ import annotations

import pathlib

W = 32
H = 32

PALETTE = {
    "#": "#171d30",  # 背景 (夜空)
    "M": "#f6efd8",  # 月
    "m": "#cfc4a2",  # 月のクレーター
    "S": "#d94b4b",  # スライム
    "s": "#a53030",  # スライム (底)
    "w": "#ff9a9a",  # スライムのハイライト
    "e": "#ffffff",  # スライムの白目
    "p": "#14181f",  # スライムの瞳
    "H": "#8a5a3b",  # 髪
    "h": "#6b4227",  # 髪 (側面)
    "F": "#f2c9a0",  # 肌
    "k": "#1a1f2e",  # 目
    "R": "#c93b3b",  # マフラー
    "B": "#3f6fd8",  # 服
    "b": "#2f55aa",  # 服 (すそ)
    "Y": "#d9a13b",  # ベルト・鍔・柄頭
    "L": "#6b4a2f",  # 脚
    "O": "#3a2a1c",  # ブーツ
    "N": "#bfeaff",  # 剣の刃
    "C": "#ffffff",  # 刃の芯
    "n": "#7fc7f0",  # 刃の先の光
    "G": "#2f5d3a",  # 草
    "g": "#24492c",  # 草 (影)
}

CELL = 8  # 1 グリッド = 8px (32×8 = 256)


def build_grid() -> list[list[str]]:
    """32×32 のピクセルグリッドを描く (y は下向き)。"""
    g: list[list[str]] = [["#"] * W for _ in range(H)]

    def rect(x: int, y: int, w: int, h: int, ch: str) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                g[yy][xx] = ch

    def px(x: int, y: int, ch: str) -> None:
        g[y][x] = ch

    # --- 満月 (右上) ---
    rect(22, 3, 4, 1, "M")
    rect(21, 4, 6, 1, "M")
    rect(20, 5, 8, 4, "M")
    rect(21, 9, 6, 1, "M")
    rect(22, 10, 4, 1, "M")
    # クレーターは省略 (16px の favicon で汚れに見えるため。v1.9 検査)

    # --- 光る剣 (左・スピンソードのイメージ) ---
    px(8, 9, "n")
    px(9, 9, "n")
    rect(8, 10, 1, 7, "N")
    rect(9, 10, 1, 7, "C")
    rect(7, 17, 4, 1, "Y")   # 鍔
    rect(8, 18, 2, 2, "H")   # 柄
    rect(8, 20, 2, 1, "Y")   # 柄頭

    # --- 主人公 (中央) ---
    rect(13, 11, 5, 1, "H")            # 髪 (上)
    px(12, 12, "h")
    rect(13, 12, 5, 1, "H")
    px(18, 12, "h")
    rect(12, 13, 1, 3, "h")            # 顔の両側 (髪)
    px(18, 13, "h")
    px(18, 14, "h")
    px(18, 15, "h")
    rect(13, 13, 5, 1, "F")            # 顔
    rect(13, 14, 5, 1, "F")
    px(14, 14, "k")                    # 目
    px(16, 14, "k")
    rect(13, 15, 5, 1, "F")
    rect(12, 16, 7, 1, "R")            # マフラー
    rect(12, 17, 7, 1, "B")            # 服
    rect(11, 18, 1, 2, "F")            # 手 (左)
    rect(12, 18, 7, 2, "B")
    px(19, 18, "F")                    # 手 (右)
    px(19, 19, "F")
    rect(12, 20, 7, 1, "Y")            # ベルト
    rect(12, 21, 7, 1, "b")            # すそ
    rect(13, 22, 2, 3, "L")            # 脚 (左)
    rect(16, 22, 2, 3, "L")            # 脚 (右)
    rect(13, 25, 2, 2, "O")            # ブーツ (左)
    rect(16, 25, 2, 2, "O")            # ブーツ (右)

    # --- 赤いスライム (右下・草の上) ---
    rect(23, 23, 4, 1, "S")
    rect(22, 24, 6, 3, "S")
    px(22, 24, "w")
    px(23, 25, "e")
    px(26, 25, "e")
    px(23, 26, "p")
    px(26, 26, "p")
    rect(23, 27, 4, 1, "s")

    # --- 草地 ---
    rect(0, 27, W, 4, "G")
    rect(0, 31, W, 1, "g")
    rect(12, 27, 7, 1, "g")            # 主人公の足元の影
    px(6, 29, "g")
    px(10, 30, "g")
    px(21, 29, "g")
    px(28, 30, "g")

    return g


def emit_svg(g: list[list[str]]) -> str:
    w, h = W * CELL, H * CELL
    rects: list[str] = []
    for y, row in enumerate(g):
        x = 0
        while x < W:
            ch = row[x]
            run = 1
            while x + run < W and row[x + run] == ch:
                run += 1
            if ch != "#":
                rects.append(
                    f'<rect x="{x * CELL}" y="{y * CELL}" width="{run * CELL}" height="{CELL}" fill="{PALETTE[ch]}"/>'
                )
            x += run
    body = "".join(rects)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" '
        f'shape-rendering="crispEdges">\n'
        f'<defs><clipPath id="frame"><rect x="0" y="0" width="{w}" height="{h}" rx="44" ry="44"/></clipPath></defs>\n'
        f'<g clip-path="url(#frame)">\n'
        f'<rect x="0" y="0" width="{w}" height="{h}" fill="{PALETTE["#"]}"/>\n'
        f"{body}\n"
        f"</g>\n"
        f'<rect x="2" y="2" width="{w - 4}" height="{h - 4}" rx="42" ry="42" fill="none" stroke="#2a3550" stroke-width="4"/>\n'
        f"</svg>\n"
    )


def main() -> None:
    g = build_grid()
    assert len(g) == H and all(len(r) == W for r in g)
    out = pathlib.Path(__file__).resolve().parent.parent / "icon.svg"
    out.write_text(emit_svg(g), encoding="utf-8", newline="\n")
    print(f"wrote {out} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
